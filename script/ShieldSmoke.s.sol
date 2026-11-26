// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {USDW} from "../src/token/USDW.sol";
import {Vault} from "../src/Vault.sol";
import {Groth16Proof, ShieldPublicInputs} from "../src/lib/Types.sol";

/// Broadcast a real Groth16 shield using contracts/script/shield_live.json
contract ShieldSmoke is Script {
    using stdJson for string;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN");
        USDW usdw = USDW(vm.envAddress("USDW"));
        Vault vault = Vault(vm.envAddress("VAULT"));

        string memory raw = vm.readFile("contracts/script/shield_live.json");
        Groth16Proof memory proof;
        proof.a[0] = raw.readUint(".a[0]");
        proof.a[1] = raw.readUint(".a[1]");
        proof.b[0][0] = raw.readUint(".b[0][0]");
        proof.b[0][1] = raw.readUint(".b[0][1]");
        proof.b[1][0] = raw.readUint(".b[1][0]");
        proof.b[1][1] = raw.readUint(".b[1][1]");
        proof.c[0] = raw.readUint(".c[0]");
        proof.c[1] = raw.readUint(".c[1]");

        bytes32 note = raw.readBytes32(".noteCommitment");
        uint256 amount = raw.readUint(".amount");
        uint32 collateralId = uint32(raw.readUint(".collateralId"));

        vm.startBroadcast(pk);
        usdw.approve(address(vault), amount);
        vault.shield(proof, ShieldPublicInputs({noteCommitment: note, collateralId: collateralId, amount: amount}));
        vm.stopBroadcast();

        console2.log("note_live", vault.isLiveNote(note));
        console2.log("leaf", vault.nextLeafIndex());
        console2.log("vault_usdw", usdw.balanceOf(address(vault)));
        console2.log("admin_usdw", usdw.balanceOf(admin));
        console2.logBytes32(vault.currentRoot());
    }
}
