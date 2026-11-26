// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {USDW} from "../src/token/USDW.sol";
import {EthUsdwSwap} from "../src/token/EthUsdwSwap.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {MockVerifier} from "../src/verifiers/MockVerifier.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {TwapOrderModule} from "../src/orders/TwapOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {
    EngineVerifiers,
    Groth16Proof,
    OpenPublicInputs,
    ShieldPublicInputs
} from "../src/lib/Types.sol";

/// Broadcasts the testnet stack (MockVerifier — proofs are not Groth16 yet).
/// forge script contracts/script/TestnetDeploy.s.sol:TestnetDeploy --rpc-url $RPC_URL --broadcast
contract TestnetDeploy is Script {
    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;

    USDW internal usdw;
    EthUsdwSwap internal swap;
    MockVerifier internal verifier;
    MockPriceOracle internal oracle;
    Vault internal vault;
    PerpEngine internal engine;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN");

        vm.startBroadcast(pk);
        _deploy(admin);
        _wireOrders();
        _listMarkets();
        _seedAndSmoke();
        vm.stopBroadcast();

        console2.log("USDW", address(usdw));
        console2.log("SWAP", address(swap));
        console2.log("VAULT", address(vault));
        console2.log("ENGINE", address(engine));
        console2.log("ORACLE", address(oracle));
        console2.log("VERIFIER", address(verifier));
        console2.log("usdw_admin", usdw.balanceOf(admin));
        console2.log("usdw_swap", usdw.balanceOf(address(swap)));
    }

    function _deploy(address admin) internal {
        uint256 ethUsd = vm.envOr("ETH_USD_1E8", uint256(2_000e8));
        usdw = new USDW(admin);
        swap = new EthUsdwSwap(admin, address(usdw), ethUsd);
        verifier = new MockVerifier();
        oracle = new MockPriceOracle();
        EngineVerifiers memory v = EngineVerifiers({
            open: address(verifier),
            close: address(verifier),
            liquidate: address(verifier),
            increase: address(verifier),
            decrease: address(verifier),
            health: address(verifier)
        });
        vault = new Vault(admin, address(usdw), address(verifier), address(verifier), address(0));
        engine = new PerpEngine(admin, address(vault), address(oracle), v);
        vault.setEngine(address(engine));
        engine.setMaxPriceAge(1 hours);
    }

    function _wireOrders() internal {
        engine.setOrderModule(OrderKind.Limit, address(new TriggerOrderModule(address(engine), OrderKind.Limit)));
        engine.setOrderModule(
            OrderKind.StopMarket, address(new TriggerOrderModule(address(engine), OrderKind.StopMarket))
        );
        engine.setOrderModule(
            OrderKind.TakeMarket, address(new TriggerOrderModule(address(engine), OrderKind.TakeMarket))
        );
        engine.setOrderModule(
            OrderKind.StopLimit, address(new TriggerOrderModule(address(engine), OrderKind.StopLimit))
        );
        engine.setOrderModule(
            OrderKind.TakeLimit, address(new TriggerOrderModule(address(engine), OrderKind.TakeLimit))
        );
        engine.setOrderModule(OrderKind.Twap, address(new TwapOrderModule(address(engine))));
    }

    function _listMarkets() internal {
        bytes32 btcId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_BTC_USD"))));
        bytes32 ethId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_ETH_USD"))));
        oracle.setPrice(btcId, vm.envOr("BTC_MARK_1E8", uint256(64_808e8)), block.timestamp);
        oracle.setPrice(ethId, vm.envOr("ETH_MARK_1E8", uint256(1_832e8)), block.timestamp);
        engine.listMarket(MARKET_BTC, btcId, 50, 100);
        engine.listMarket(MARKET_ETH, ethId, 50, 100);
    }

    function _seedAndSmoke() internal {
        usdw.transfer(address(swap), vm.envOr("SWAP_SEED_USDW", uint256(10_000_000e6)));
        usdw.approve(address(vault), type(uint256).max);
        Groth16Proof memory proof;
        vault.shield(
            proof,
            ShieldPublicInputs({
                noteCommitment: keccak256("winx-smoke-note"),
                collateralId: 1,
                amount: 1_000e6
            })
        );
        engine.open(
            proof,
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("winx-smoke-null"),
                positionCommitment: keccak256("winx-smoke-pos"),
                changeNoteCommitment: bytes32(0),
                markPrice: vm.envOr("BTC_MARK_1E8", uint256(64_808e8)),
                openedAt: block.timestamp,
                marketId: MARKET_BTC,
                collateralId: 1
            })
        );
        swap.swap{value: 0.0005 ether}();
    }
}
