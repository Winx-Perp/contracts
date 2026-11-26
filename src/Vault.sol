// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGroth16Verifier} from "./interfaces/IGroth16Verifier.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Auth, ReentrancyGuard} from "./lib/Auth.sol";
import {IHasher, KeccakHasher} from "./lib/Hasher.sol";
import {IncrementalMerkleTree} from "./lib/IncrementalMerkleTree.sol";
import {PublicInputs} from "./lib/PublicInputs.sol";
import {IERC20, SafeERC20} from "./lib/SafeERC20.sol";
import {Collateral, Groth16Proof, ShieldPublicInputs, UnshieldPublicInputs} from "./lib/Types.sol";

/// @title Vault
/// @notice Shielded collateral. USDW is primary (id 1). Admin can list more
/// ERC-20s later; notes bind `collateralId` so tokens cannot be mixed.
contract Vault is IVault, Auth, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using IncrementalMerkleTree for IncrementalMerkleTree.Data;

    error InvalidProof();
    error InvalidCommitment();
    error NoteUnknown();
    error NoteTaken();
    error NullifierUsed();
    error UnknownRoot();
    error ZeroAmount();
    error Paused();
    error UnknownCollateral();
    error CollateralNotListed();
    error CollateralTaken();
    error BadCollateral();
    error InsufficientPool();

    uint32 public constant PRIMARY_COLLATERAL = 1;

    IGroth16Verifier public shieldVerifier;
    IGroth16Verifier public unshieldVerifier;
    IHasher public hasher;

    bool public paused;
    mapping(uint32 => Collateral) public collaterals;
    mapping(address => uint32) public collateralIdOf;

    IncrementalMerkleTree.Data internal tree;
    mapping(bytes32 => bool) public notes;
    mapping(bytes32 => bool) public nullifiers;
    /// @notice Admin house inventory per collateral. Winner unshields pay from
    /// vault ERC-20; this is the withdrawable surplus (not trader notes).
    mapping(uint32 => uint256) public poolBalance;

    event Shielded(
        bytes32 indexed commitment, uint32 indexed collateralId, uint256 amount, address indexed from
    );
    event Unshielded(
        bytes32 indexed merkleRoot, bytes32 indexed nullifier, uint32 collateralId, uint256 amount, address indexed to
    );
    event NoteSpent(bytes32 indexed nullifier, bytes32 changeCommitment);
    event NoteInserted(bytes32 indexed commitment);
    event CollateralAdded(uint32 indexed id, address token, uint8 decimals, bool marginEnabled);
    event CollateralUpdated(uint32 indexed id, bool listed, bool marginEnabled);
    event VerifiersUpdated(address shieldVerifier, address unshieldVerifier);
    event HasherUpdated(address hasher);
    event PausedUpdated(bool paused);
    event PoolDeposited(uint32 indexed collateralId, uint256 amount, address indexed from);
    event PoolWithdrawn(uint32 indexed collateralId, uint256 amount, address indexed to);
    event ProtocolPaid(uint32 indexed collateralId, address indexed to, uint256 amount);

    constructor(address owner_, address usdw_, address shieldVerifier_, address unshieldVerifier_, address hasher_)
        Auth(owner_)
    {
        if (usdw_ == address(0) || shieldVerifier_ == address(0) || unshieldVerifier_ == address(0)) {
            revert ZeroAddress();
        }
        shieldVerifier = IGroth16Verifier(shieldVerifier_);
        unshieldVerifier = IGroth16Verifier(unshieldVerifier_);
        hasher = hasher_ == address(0) ? IHasher(address(new KeccakHasher())) : IHasher(hasher_);
        tree.init(hasher);
        _addCollateral(PRIMARY_COLLATERAL, usdw_, 6, true);
    }

    /// @notice Primary margin token (USDW at deploy).
    function token() public view returns (IERC20) {
        return IERC20(collaterals[PRIMARY_COLLATERAL].token);
    }

    function marginEnabled(uint32 collateralId) external view returns (bool) {
        Collateral storage c = collaterals[collateralId];
        return c.listed && c.marginEnabled;
    }

    function addCollateral(uint32 id, address token_, uint8 decimals, bool marginEnabled_) external onlyOwner {
        _addCollateral(id, token_, decimals, marginEnabled_);
    }

    function setCollateral(uint32 id, bool listed, bool marginEnabled_) external onlyOwner {
        Collateral storage c = collaterals[id];
        if (c.token == address(0)) revert UnknownCollateral();
        if (id == PRIMARY_COLLATERAL && (!listed || !marginEnabled_)) revert BadCollateral();
        c.listed = listed;
        c.marginEnabled = marginEnabled_;
        emit CollateralUpdated(id, listed, marginEnabled_);
    }

    function setVerifiers(address shieldVerifier_, address unshieldVerifier_) external onlyOwner {
        if (shieldVerifier_ == address(0) || unshieldVerifier_ == address(0)) revert ZeroAddress();
        shieldVerifier = IGroth16Verifier(shieldVerifier_);
        unshieldVerifier = IGroth16Verifier(unshieldVerifier_);
        emit VerifiersUpdated(shieldVerifier_, unshieldVerifier_);
    }

    function setHasher(address hasher_) external onlyOwner {
        if (hasher_ == address(0)) revert ZeroAddress();
        hasher = IHasher(hasher_);
        emit HasherUpdated(hasher_);
    }

    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedUpdated(paused_);
    }

    /// @notice Seed house USDW (or other listed collateral) used to pay winning PnL.
    function depositPool(uint32 collateralId, uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Collateral storage c = _known(collateralId);
        IERC20(c.token).safeTransferFrom(msg.sender, address(this), amount);
        poolBalance[collateralId] += amount;
        emit PoolDeposited(collateralId, amount, msg.sender);
    }

    function withdrawPool(uint32 collateralId, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > poolBalance[collateralId]) revert InsufficientPool();
        poolBalance[collateralId] -= amount;
        IERC20(collaterals[collateralId].token).safeTransfer(to, amount);
        emit PoolWithdrawn(collateralId, amount, to);
    }

    function scope() public view returns (uint256) {
        return uint256(uint160(address(this)));
    }

    function currentRoot() public view returns (bytes32) {
        return tree.currentRoot;
    }

    function isKnownRoot(bytes32 root) public view returns (bool) {
        return root != bytes32(0) && tree.knownRoot[root];
    }

    function isLiveNote(bytes32 commitment) external view returns (bool) {
        return notes[commitment];
    }

    function isSpentNullifier(bytes32 nullifier) external view returns (bool) {
        return nullifiers[nullifier];
    }

    function nextLeafIndex() external view returns (uint32) {
        return tree.nextIndex;
    }

    function shield(Groth16Proof calldata proof, ShieldPublicInputs calldata inputs) external nonReentrant {
        if (paused) revert Paused();
        if (inputs.amount == 0) revert ZeroAmount();
        if (inputs.noteCommitment == bytes32(0) || notes[inputs.noteCommitment]) {
            revert InvalidCommitment();
        }
        Collateral storage c = _listed(inputs.collateralId);

        uint256[] memory pub = PublicInputs.packShield(inputs, scope());
        if (!shieldVerifier.verifyProof(proof.a, proof.b, proof.c, pub)) revert InvalidProof();

        notes[inputs.noteCommitment] = true;
        tree.insert(inputs.noteCommitment);
        IERC20(c.token).safeTransferFrom(msg.sender, address(this), inputs.amount);
        emit Shielded(inputs.noteCommitment, inputs.collateralId, inputs.amount, msg.sender);
    }

    function unshield(Groth16Proof calldata proof, UnshieldPublicInputs calldata inputs) external nonReentrant {
        if (paused) revert Paused();
        if (inputs.amount == 0) revert ZeroAmount();
        if (inputs.recipient == address(0)) revert ZeroAddress();
        if (!isKnownRoot(inputs.merkleRoot)) revert UnknownRoot();
        Collateral storage c = _known(inputs.collateralId);
        _spendNullifier(inputs.noteNullifier);

        uint256[] memory pub = PublicInputs.packUnshield(inputs, scope());
        if (!unshieldVerifier.verifyProof(proof.a, proof.b, proof.c, pub)) revert InvalidProof();

        IERC20(c.token).safeTransfer(inputs.recipient, inputs.amount);
        _syncPool(inputs.collateralId);
        emit Unshielded(inputs.merkleRoot, inputs.noteNullifier, inputs.collateralId, inputs.amount, inputs.recipient);
    }

    function spendNote(bytes32 nullifier, bytes32 changeCommitment, bytes32 merkleRoot) external onlyEngine {
        if (!isKnownRoot(merkleRoot)) revert UnknownRoot();
        _spendNullifier(nullifier);
        if (changeCommitment != bytes32(0)) {
            _insertLeaf(changeCommitment);
        }
        emit NoteSpent(nullifier, changeCommitment);
    }

    function insertNote(bytes32 commitment) external onlyEngine {
        _insertLeaf(commitment);
        emit NoteInserted(commitment);
    }

    /// @notice Engine pays profit fees / seized liquidation margin to the PnL pool.
    function payProtocol(uint32 collateralId, address to, uint256 amount) external onlyEngine nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        Collateral storage c = _known(collateralId);
        IERC20(c.token).safeTransfer(to, amount);
        _syncPool(collateralId);
        emit ProtocolPaid(collateralId, to, amount);
    }

    function _addCollateral(uint32 id, address token_, uint8 decimals, bool marginEnabled_) internal {
        if (id == 0 || token_ == address(0) || decimals == 0) revert BadCollateral();
        if (collaterals[id].token != address(0) || collateralIdOf[token_] != 0) revert CollateralTaken();
        collaterals[id] = Collateral({token: token_, decimals: decimals, listed: true, marginEnabled: marginEnabled_});
        collateralIdOf[token_] = id;
        emit CollateralAdded(id, token_, decimals, marginEnabled_);
    }

    function _listed(uint32 id) internal view returns (Collateral storage c) {
        c = _known(id);
        if (!c.listed) revert CollateralNotListed();
    }

    function _known(uint32 id) internal view returns (Collateral storage c) {
        c = collaterals[id];
        if (c.token == address(0)) revert UnknownCollateral();
    }

    function _insertLeaf(bytes32 commitment) internal {
        if (commitment == bytes32(0)) revert InvalidCommitment();
        if (notes[commitment]) revert NoteTaken();
        notes[commitment] = true;
        tree.insert(commitment);
    }

    function _spendNullifier(bytes32 nullifier) internal {
        if (nullifier == bytes32(0) || nullifiers[nullifier]) revert NullifierUsed();
        nullifiers[nullifier] = true;
    }

    /// Winner payouts can consume house inventory. Cap pool to tokens still held.
    function _syncPool(uint32 collateralId) internal {
        uint256 held = IERC20(collaterals[collateralId].token).balanceOf(address(this));
        if (poolBalance[collateralId] > held) poolBalance[collateralId] = held;
    }
}
