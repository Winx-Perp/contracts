// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {USDW} from "../src/token/USDW.sol";
import {PnlPool} from "../src/PnlPool.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {MockVerifier} from "../src/verifiers/MockVerifier.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {TwapOrderModule} from "../src/orders/TwapOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {
    ClosePublicInputs,
    EngineVerifiers,
    Groth16Proof,
    LiquidatePublicInputs,
    OpenPublicInputs,
    ShieldPublicInputs
} from "../src/lib/Types.sol";
import {PerpMath} from "../src/lib/PerpMath.sol";

/// Redeploy vault+engine+pool with 0.1% profit fee + liquidation seize, fund 100M, smoke.
contract TestnetRedeployFees is Script {
    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;
    uint256 internal constant SEED = 100_000_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN");
        USDW usdw = USDW(vm.envAddress("USDW"));
        bytes32 btcId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_BTC_USD"))));
        bytes32 ethId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_ETH_USD"))));
        uint256 btcPx = vm.envOr("BTC_MARK_1E8", uint256(64_808e8));
        uint256 ethPx = vm.envOr("ETH_MARK_1E8", uint256(1_832e8));

        vm.startBroadcast(pk);

        MockVerifier verifier = new MockVerifier();
        MockPriceOracle oracle = new MockPriceOracle();
        oracle.setPrice(btcId, btcPx, block.timestamp);
        oracle.setPrice(ethId, ethPx, block.timestamp);

        PnlPool pool = new PnlPool(admin, address(usdw));
        Vault vault = new Vault(admin, address(usdw), address(verifier), address(verifier), address(0));
        EngineVerifiers memory v = EngineVerifiers({
            open: address(verifier),
            close: address(verifier),
            liquidate: address(verifier),
            increase: address(verifier),
            decrease: address(verifier),
            health: address(verifier)
        });
        PerpEngine engine = new PerpEngine(admin, address(vault), address(oracle), v);
        vault.setEngine(address(engine));
        engine.setPnlPool(address(pool));
        pool.setEngine(address(engine));
        engine.setMaxPriceAge(1 hours);
        engine.setProfitFeeBps(10);

        engine.setOrderModule(OrderKind.Limit, address(new TriggerOrderModule(address(engine), OrderKind.Limit)));
        engine.setOrderModule(
            OrderKind.StopMarket, address(new TriggerOrderModule(address(engine), OrderKind.StopMarket))
        );
        engine.setOrderModule(
            OrderKind.TakeMarket, address(new TriggerOrderModule(address(engine), OrderKind.TakeMarket))
        );
        engine.setOrderModule(OrderKind.Twap, address(new TwapOrderModule(address(engine))));

        engine.listMarket(MARKET_BTC, btcId, 40, 100);
        engine.listMarket(MARKET_ETH, ethId, 30, 100);

        usdw.approve(address(pool), SEED);
        pool.deposit(SEED);
        // Cover vault so fee/seize smoke has inventory headroom.
        pool.cover(address(vault), 1_000_000e6);
        usdw.approve(address(vault), type(uint256).max);

        Groth16Proof memory proof;
        // Shield + open + close with 0.1% fee on $1,000 notional profit → fee $1.
        vault.shield(
            proof, ShieldPublicInputs({noteCommitment: keccak256("fee-note"), collateralId: 1, amount: 1_000e6})
        );
        engine.open(
            proof,
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("fee-null"),
                positionCommitment: keccak256("fee-pos"),
                changeNoteCommitment: bytes32(0),
                markPrice: btcPx,
            openedAt: block.timestamp,
                marketId: MARKET_BTC,
                collateralId: 1
            })
        );
        uint256 fee = PerpMath.profitFee(1_000e6, 10); // $1 if profit were $1000
        engine.close(
            proof,
            ClosePublicInputs({
                positionCommitment: keccak256("fee-pos"),
                positionNullifier: keccak256("fee-pos-null"),
                payoutNoteCommitment: keccak256("fee-payout"),
                exitPrice: btcPx,
                protocolFee: fee,
                marketId: MARKET_BTC,
                collateralId: 1
            })
        );

        // Liquidation seize $100 of margin into the pool.
        vault.shield(
            proof, ShieldPublicInputs({noteCommitment: keccak256("liq-note"), collateralId: 1, amount: 100e6})
        );
        engine.open(
            proof,
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("liq-null"),
                positionCommitment: keccak256("liq-pos"),
                changeNoteCommitment: bytes32(0),
                markPrice: ethPx,
            openedAt: block.timestamp,
                marketId: MARKET_ETH,
                collateralId: 1
            })
        );
        engine.liquidate(
            proof,
            LiquidatePublicInputs({
                positionCommitment: keccak256("liq-pos"),
                positionNullifier: keccak256("liq-pos-null"),
                leftoverNoteCommitment: bytes32(0),
                exitPrice: ethPx,
                seizedAmount: 100e6,
                marketId: MARKET_ETH,
                collateralId: 1,
                closedAt: block.timestamp
            })
        );

        vm.stopBroadcast();

        console2.log("USDW", address(usdw));
        console2.log("VAULT", address(vault));
        console2.log("ENGINE", address(engine));
        console2.log("ORACLE", address(oracle));
        console2.log("VERIFIER", address(verifier));
        console2.log("PNL_POOL", address(pool));
        console2.log("house", pool.houseBalance());
        console2.log("fees", pool.feesAccrued());
        console2.log("seized", pool.seizedAccrued());
        console2.log("profitFeeBps", engine.profitFeeBps());
    }
}
