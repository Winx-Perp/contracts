// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {Groth16Proof, OpenPublicInputs} from "../src/lib/Types.sol";

/// Broadcast a real Groth16 open using contracts/script/open_live.json
contract OpenSmoke is Script {
    using stdJson for string;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        PerpEngine engine = PerpEngine(vm.envAddress("ENGINE"));

        string memory raw = vm.readFile("contracts/script/open_live.json");
        Groth16Proof memory proof;
        proof.a[0] = raw.readUint(".a[0]");
        proof.a[1] = raw.readUint(".a[1]");
        proof.b[0][0] = raw.readUint(".b[0][0]");
        proof.b[0][1] = raw.readUint(".b[0][1]");
        proof.b[1][0] = raw.readUint(".b[1][0]");
        proof.b[1][1] = raw.readUint(".b[1][1]");
        proof.c[0] = raw.readUint(".c[0]");
        proof.c[1] = raw.readUint(".c[1]");

        OpenPublicInputs memory inputs = OpenPublicInputs({
            merkleRoot: raw.readBytes32(".merkleRoot"),
            noteNullifier: raw.readBytes32(".noteNullifier"),
            positionCommitment: raw.readBytes32(".positionCommitment"),
            changeNoteCommitment: raw.readBytes32(".changeNoteCommitment"),
            markPrice: raw.readUint(".markPrice"),
            openedAt: raw.readUint(".openedAt"),
            marketId: uint32(raw.readUint(".marketId")),
            collateralId: uint32(raw.readUint(".collateralId"))
        });

        console2.log("chain_ts", block.timestamp);
        console2.log("proof_openedAt", inputs.openedAt);

        vm.startBroadcast(pk);
        engine.open(proof, inputs);
        vm.stopBroadcast();

        console2.log("position_live", engine.positions(inputs.positionCommitment));
        console2.logBytes32(inputs.positionCommitment);
    }
}
