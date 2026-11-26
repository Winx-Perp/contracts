// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {USDW} from "../src/token/USDW.sol";
import {EthUsdwSwap} from "../src/token/EthUsdwSwap.sol";
import {Vault} from "../src/Vault.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {Groth16Proof, OpenPublicInputs} from "../src/lib/Types.sol";

/// Continues smoke on an already-broadcast TestnetDeploy (shield landed, open reverted StalePrice).
contract TestnetSmoke is Script {
    uint32 internal constant MARKET_BTC = 1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN");
        USDW usdw = USDW(vm.envAddress("USDW"));
        EthUsdwSwap swap = EthUsdwSwap(payable(vm.envAddress("ETH_USDW_SWAP")));
        Vault vault = Vault(vm.envAddress("VAULT"));
        PerpEngine engine = PerpEngine(vm.envAddress("ENGINE"));
        MockPriceOracle oracle = MockPriceOracle(vm.envAddress("ORACLE"));
        bytes32 btcId = bytes32(uint256(uint160(vm.envAddress("CHAINLINK_BTC_USD"))));
        uint256 btcPx = vm.envOr("BTC_MARK_1E8", uint256(64_808e8));

        vm.startBroadcast(pk);
        engine.setMaxPriceAge(1 hours);
        oracle.setPrice(btcId, btcPx, block.timestamp);
        Groth16Proof memory proof;
        engine.open(
            proof,
            OpenPublicInputs({
                merkleRoot: vault.currentRoot(),
                noteNullifier: keccak256("winx-smoke-null"),
                positionCommitment: keccak256("winx-smoke-pos"),
                changeNoteCommitment: bytes32(0),
                markPrice: btcPx,
            openedAt: block.timestamp,
                marketId: MARKET_BTC,
                collateralId: 1
            })
        );
        swap.swap{value: 0.0005 ether}();
        vm.stopBroadcast();

        console2.log("open_ok", engine.positions(keccak256("winx-smoke-pos")));
        console2.log("usdw_admin", usdw.balanceOf(admin));
        console2.log("usdw_swap", usdw.balanceOf(address(swap)));
        console2.log("usdw_vault", usdw.balanceOf(address(vault)));
        console2.log("maxPriceAge", engine.maxPriceAge());
    }
}
