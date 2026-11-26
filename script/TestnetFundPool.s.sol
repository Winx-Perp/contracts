// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {USDW} from "../src/token/USDW.sol";
import {PnlPool} from "../src/PnlPool.sol";

/// Deploys the house PnL pool and seeds 100M USDW. Admin deposit/withdraw/cover.
contract TestnetFundPool is Script {
    uint256 internal constant SEED = 100_000_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN");
        USDW usdw = USDW(vm.envAddress("USDW"));
        address vault = vm.envAddress("VAULT");

        vm.startBroadcast(pk);
        PnlPool pool = new PnlPool(admin, address(usdw));
        usdw.approve(address(pool), SEED);
        pool.deposit(SEED);
        vm.stopBroadcast();

        console2.log("PNL_POOL", address(pool));
        console2.log("VAULT", vault);
        console2.log("pool_balance", pool.balance());
        console2.log("usdw_admin", usdw.balanceOf(admin));
        console2.log("usdw_vault", usdw.balanceOf(vault));
    }
}
