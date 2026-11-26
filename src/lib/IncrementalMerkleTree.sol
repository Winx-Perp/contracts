// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHasher} from "./Hasher.sol";

library IncrementalMerkleTree {
    uint32 internal constant DEPTH = 16;
    uint32 internal constant ROOT_HISTORY = 32;

    struct Data {
        IHasher hasher;
        uint32 nextIndex;
        uint32 historyIndex;
        bytes32 currentRoot;
        mapping(uint256 => bytes32) filledSubtrees;
        mapping(uint256 => bytes32) zeros;
        mapping(uint256 => bytes32) roots;
        mapping(bytes32 => bool) knownRoot;
    }

    function init(Data storage self, IHasher hasher_) internal {
        self.hasher = hasher_;
        bytes32 z = bytes32(0);
        self.zeros[0] = z;
        self.filledSubtrees[0] = z;
        for (uint256 i = 0; i < DEPTH; ++i) {
            z = hasher_.hashLeftRight(z, z);
            self.zeros[i + 1] = z;
            if (i + 1 < DEPTH) self.filledSubtrees[i + 1] = z;
        }
        self.currentRoot = z;
        self.knownRoot[z] = true;
        self.roots[0] = z;
    }

    function insert(Data storage self, bytes32 leaf) internal returns (uint32 index) {
        index = self.nextIndex;
        require(index < uint32(1) << DEPTH, "tree full");
        self.nextIndex = index + 1;

        bytes32 current = leaf;
        uint32 idx = index;
        for (uint32 i = 0; i < DEPTH; ++i) {
            if (idx % 2 == 0) {
                self.filledSubtrees[i] = current;
                current = self.hasher.hashLeftRight(current, self.zeros[i]);
            } else {
                current = self.hasher.hashLeftRight(self.filledSubtrees[i], current);
            }
            idx /= 2;
        }
        self.currentRoot = current;
        uint32 h = (self.historyIndex + 1) % ROOT_HISTORY;
        self.historyIndex = h;
        bytes32 old = self.roots[h];
        if (old != bytes32(0)) self.knownRoot[old] = false;
        self.roots[h] = current;
        self.knownRoot[current] = true;
    }
}
