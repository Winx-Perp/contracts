// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {USDW} from "../src/token/USDW.sol";
import {EthUsdwSwap} from "../src/token/EthUsdwSwap.sol";
import {PnlPool} from "../src/PnlPool.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {PoseidonHasher} from "../src/lib/Hasher.sol";
import {ChainlinkOracleAdapter} from "../src/oracle/ChainlinkOracleAdapter.sol";
import {AggregatorV3Feed} from "../src/oracle/AggregatorV3Feed.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {TwapOrderModule} from "../src/orders/TwapOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {Timelock} from "../src/admin/Timelock.sol";
import {Multisig} from "../src/admin/Multisig.sol";
import {EngineVerifiers} from "../src/lib/Types.sol";
import {ShieldVerifier} from "../src/verifiers/generated/ShieldVerifier.sol";
import {UnshieldVerifier} from "../src/verifiers/generated/UnshieldVerifier.sol";
import {OpenVerifier} from "../src/verifiers/generated/OpenVerifier.sol";
import {CloseVerifier} from "../src/verifiers/generated/CloseVerifier.sol";
import {LiquidateVerifier} from "../src/verifiers/generated/LiquidateVerifier.sol";
import {IncreaseVerifier} from "../src/verifiers/generated/IncreaseVerifier.sol";
import {DecreaseVerifier} from "../src/verifiers/generated/DecreaseVerifier.sol";
import {HealthVerifier} from "../src/verifiers/generated/HealthVerifier.sol";
import {
    ShieldVerifierAdapter,
    UnshieldVerifierAdapter,
    OpenVerifierAdapter,
    CloseVerifierAdapter,
    LiquidateVerifierAdapter,
    IncreaseVerifierAdapter,
    DecreaseVerifierAdapter,
    HealthVerifierAdapter
} from "../src/verifiers/VerifierAdapters.sol";

/// Groth16 + Poseidon + Chainlink-shaped feeds. No MockVerifier / MockPriceOracle.
contract ProductionDeploy is Script {
    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN");
        address existingUsdw = vm.envOr("USDW", address(0));
        uint256 ethUsd = vm.envOr("ETH_USD_1E8", uint256(2_000e8));
        uint256 seed = vm.envOr("SWAP_SEED_USDW", uint256(10_000_000e6));
        uint256 house = vm.envOr("HOUSE_SEED_USDW", uint256(100_000_000e6));
        int256 btcPx = int256(vm.envOr("BTC_MARK_1E8", uint256(64_808e8)));
        int256 ethPx = int256(vm.envOr("ETH_MARK_1E8", uint256(1_832e8)));

        vm.startBroadcast(pk);

        USDW usdw = existingUsdw == address(0) ? new USDW(admin) : USDW(existingUsdw);
        EthUsdwSwap swap = new EthUsdwSwap(admin, address(usdw), ethUsd);
        PnlPool pool = new PnlPool(admin, address(usdw));

        address poseidon2 = _deployPoseidon2();
        PoseidonHasher hasher = new PoseidonHasher(poseidon2);

        address shield = address(new ShieldVerifierAdapter(address(new ShieldVerifier())));
        address unshield = address(new UnshieldVerifierAdapter(address(new UnshieldVerifier())));
        EngineVerifiers memory v = EngineVerifiers({
            open: address(new OpenVerifierAdapter(address(new OpenVerifier()))),
            close: address(new CloseVerifierAdapter(address(new CloseVerifier()))),
            liquidate: address(new LiquidateVerifierAdapter(address(new LiquidateVerifier()))),
            increase: address(new IncreaseVerifierAdapter(address(new IncreaseVerifier()))),
            decrease: address(new DecreaseVerifierAdapter(address(new DecreaseVerifier()))),
            health: address(new HealthVerifierAdapter(address(new HealthVerifier())))
        });

        ChainlinkOracleAdapter oracle = new ChainlinkOracleAdapter();
        AggregatorV3Feed btcFeed = new AggregatorV3Feed(admin, 8, "BTC / USD");
        AggregatorV3Feed ethFeed = new AggregatorV3Feed(admin, 8, "ETH / USD");
        btcFeed.setAnswer(btcPx);
        ethFeed.setAnswer(ethPx);

        Vault vault = new Vault(admin, address(usdw), shield, unshield, address(hasher));
        PerpEngine engine = new PerpEngine(admin, address(vault), address(oracle), v);
        vault.setEngine(address(engine));
        engine.setPnlPool(address(pool));
        pool.setEngine(address(engine));
        engine.setMaxPriceAge(1 hours);
        engine.setMaxOpenAge(120);
        engine.setProfitFeeBps(10);

        _wireOrders(engine);
        engine.listMarket(MARKET_BTC, oracle.feedIdOf(address(btcFeed)), 40, 100);
        engine.listMarket(MARKET_ETH, oracle.feedIdOf(address(ethFeed)), 30, 100);

        usdw.transfer(address(swap), seed);
        usdw.approve(address(pool), house);
        pool.deposit(house);
        pool.cover(address(vault), 1_000_000e6);

        address[] memory signers = new address[](1);
        signers[0] = admin;
        Multisig ms = new Multisig(signers, 1);
        Timelock lock = new Timelock(address(ms), 0);

        vm.stopBroadcast();

        console2.log("USDW", address(usdw));
        console2.log("SWAP", address(swap));
        console2.log("VAULT", address(vault));
        console2.log("ENGINE", address(engine));
        console2.log("ORACLE", address(oracle));
        console2.log("BTC_FEED", address(btcFeed));
        console2.log("ETH_FEED", address(ethFeed));
        console2.log("PNL_POOL", address(pool));
        console2.log("POSEIDON2", poseidon2);
        console2.log("HASHER", address(hasher));
        console2.log("SHIELD_V", shield);
        console2.log("OPEN_V", v.open);
        console2.log("CLOSE_V", v.close);
        console2.log("LIQ_V", v.liquidate);
        console2.log("TIMELOCK", address(lock));
        console2.log("MULTISIG", address(ms));
        console2.log("profitFeeBps", engine.profitFeeBps());
        console2.log("house", pool.houseBalance());
    }

    function _wireOrders(PerpEngine engine) internal {
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

    function _deployPoseidon2() internal returns (address addr) {
        bytes memory bytecode = vm.parseBytes(vm.readFile("contracts/script/poseidon2.hex"));
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(addr != address(0), "poseidon create failed");
    }
}
