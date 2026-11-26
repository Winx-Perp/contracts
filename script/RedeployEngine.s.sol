// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {PnlPool} from "../src/PnlPool.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {TwapOrderModule} from "../src/orders/TwapOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {EngineVerifiers} from "../src/lib/Types.sol";

/// Redeploy PerpEngine (openedAt skew) against existing vault/oracle/verifiers/pool.
contract RedeployEngine is Script {
    uint32 internal constant MARKET_BTC = 1;
    uint32 internal constant MARKET_ETH = 2;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN");
        Vault vault = Vault(vm.envAddress("VAULT"));
        PnlPool pool = PnlPool(vm.envAddress("PNL_POOL"));
        address oracle = vm.envAddress("ORACLE");
        address btcFeed = vm.envAddress("BTC_FEED");
        address ethFeed = vm.envAddress("ETH_FEED");
        PerpEngine old = PerpEngine(vm.envAddress("ENGINE"));

        EngineVerifiers memory v = EngineVerifiers({
            open: address(old.openVerifier()),
            close: address(old.closeVerifier()),
            liquidate: address(old.liquidateVerifier()),
            increase: address(old.increaseVerifier()),
            decrease: address(old.decreaseVerifier()),
            health: address(old.healthVerifier())
        });

        bytes32 btcId = bytes32(uint256(uint160(btcFeed)));
        bytes32 ethId = bytes32(uint256(uint160(ethFeed)));

        vm.startBroadcast(pk);
        PerpEngine engine = new PerpEngine(admin, address(vault), oracle, v);
        vault.setEngine(address(engine));
        engine.setPnlPool(address(pool));
        pool.setEngine(address(engine));
        engine.setMaxPriceAge(1 hours);
        engine.setMaxOpenAge(120);
        engine.setMaxLiqAge(300);
        engine.setProfitFeeBps(10);

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

        engine.listMarket(MARKET_BTC, btcId, 40, 100);
        engine.listMarket(MARKET_ETH, ethId, 30, 100);
        vm.stopBroadcast();

        console2.log("ENGINE", address(engine));
        console2.log("maxOpenAge", engine.maxOpenAge());
        console2.log("maxLiqAge", engine.maxLiqAge());
    }
}
