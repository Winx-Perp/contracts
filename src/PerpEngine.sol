// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGroth16Verifier} from "./interfaces/IGroth16Verifier.sol";
import {IOrderModule} from "./interfaces/IOrderModule.sol";
import {IPnlPool} from "./interfaces/IPnlPool.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Auth, ReentrancyGuard} from "./lib/Auth.sol";
import {PerpMath} from "./lib/PerpMath.sol";
import {PublicInputs} from "./lib/PublicInputs.sol";
import {
    ClosePublicInputs,
    DecreasePublicInputs,
    EngineVerifiers,
    Groth16Proof,
    HealthPublicInputs,
    HealthState,
    IncreasePublicInputs,
    LiquidatePublicInputs,
    Market,
    OpenPublicInputs
} from "./lib/Types.sol";
import {OrderKind} from "./orders/OrderTypes.sol";

/// @title PerpEngine
/// @notice Private vAMM perp. Positions are commitments. Funding is epoch-batched
/// skew (not per-trade OI). Health commitments let keepers liquidate without the
/// full witness. Limit/Stop/Take/TWAP run through registered modules.
///
/// Liquidation is not a price-watcher inside the contract. Traders (or keepers)
/// must refresh `updateHealth`; keepers call `liquidateFromHealth` when the flag
/// is set or health is stale. Seized margin and 0.1% profit fees go to `pnlPool`.
contract PerpEngine is Auth, ReentrancyGuard {
    error InvalidProof();
    error PositionUnknown();
    error PositionTaken();
    error NullifierUsed();
    error MarketNotListed();
    error StalePrice();
    error PriceMismatch();
    error Paused();
    error OrderModuleUnset(OrderKind kind);
    error OrderModuleKindMismatch();
    error EpochNotReady();
    error HealthFresh();
    error NotLiquidatable();
    error CollateralDisabled();
    error PoolUnset();
    error FeeTooHigh();
    error StaleOpen();
    error StaleLiquidation();

    IVault public vault;
    IPriceOracle public oracle;
    IPnlPool public pnlPool;
    IGroth16Verifier public openVerifier;
    IGroth16Verifier public closeVerifier;
    IGroth16Verifier public liquidateVerifier;
    IGroth16Verifier public increaseVerifier;
    IGroth16Verifier public decreaseVerifier;
    IGroth16Verifier public healthVerifier;

    uint256 public maxPriceAge = 60;
    /// @notice Proof `openedAt` may lag `block.timestamp` by this many seconds (prove→submit).
    uint256 public maxOpenAge = 120;
    /// @notice Liquidation proof `closedAt` may lag inclusion by this many seconds.
    uint256 public maxLiqAge = 300;
    uint256 public maxHealthAge = 1 hours;
    /// @notice 10 = 0.1% of positive PnL on close/decrease.
    uint32 public profitFeeBps = 10;
    bool public paused;

    mapping(uint32 => Market) public markets;
    mapping(bytes32 => bool) public positions;
    mapping(bytes32 => bool) public nullifiers;
    mapping(bytes32 => HealthState) public health;
    mapping(OrderKind => IOrderModule) public orderModules;

    event MarketListed(uint32 indexed marketId, bytes32 pythFeedId, uint32 maxLeverage, uint32 maintenanceMarginBps);
    event MarketDelisted(uint32 indexed marketId);
    event RiskParamsUpdated(uint32 indexed marketId);
    event OiPublished(uint32 indexed marketId, uint256 longOi, uint256 shortOi);
    event EpochSealed(uint32 indexed marketId, int256 fundingIndexLong, int256 fundingIndexShort, uint256 impactBps);
    event PositionOpened(bytes32 indexed positionCommitment, bytes32 indexed noteNullifier, uint32 indexed marketId);
    event PositionIncreased(bytes32 indexed oldPos, bytes32 indexed newPos);
    event PositionDecreased(bytes32 indexed oldPos, bytes32 indexed newPos);
    event PositionClosed(bytes32 indexed positionCommitment, bytes32 indexed nullifier, bytes32 payoutNote);
    event PositionLiquidated(bytes32 indexed positionCommitment, bytes32 indexed nullifier, bytes32 leftoverNote);
    event HealthUpdated(bytes32 indexed positionCommitment, bytes32 healthCommitment, bool liquidatable);
    event VerifiersUpdated();
    event OracleUpdated(address oracle);
    event VaultUpdated(address vault);
    event MaxPriceAgeUpdated(uint256 maxPriceAge);
    event MaxOpenAgeUpdated(uint256 maxOpenAge);
    event MaxLiqAgeUpdated(uint256 maxLiqAge);
    event MaxHealthAgeUpdated(uint256 maxHealthAge);
    event ProfitFeeBpsUpdated(uint32 profitFeeBps);
    event PnlPoolUpdated(address pnlPool);
    event ProtocolFeePaid(bytes32 indexed position, uint256 amount);
    event MarginSeized(bytes32 indexed position, uint256 amount);
    event PausedUpdated(bool paused);
    event OrderModuleUpdated(OrderKind indexed kind, address module);

    constructor(address owner_, address vault_, address oracle_, EngineVerifiers memory v) Auth(owner_) {
        if (vault_ == address(0) || oracle_ == address(0)) revert ZeroAddress();
        if (
            v.open == address(0) || v.close == address(0) || v.liquidate == address(0) || v.increase == address(0)
                || v.decrease == address(0) || v.health == address(0)
        ) revert ZeroAddress();
        vault = IVault(vault_);
        oracle = IPriceOracle(oracle_);
        openVerifier = IGroth16Verifier(v.open);
        closeVerifier = IGroth16Verifier(v.close);
        liquidateVerifier = IGroth16Verifier(v.liquidate);
        increaseVerifier = IGroth16Verifier(v.increase);
        decreaseVerifier = IGroth16Verifier(v.decrease);
        healthVerifier = IGroth16Verifier(v.health);
    }

    function setVault(address vault_) external onlyOwner {
        if (vault_ == address(0)) revert ZeroAddress();
        vault = IVault(vault_);
        emit VaultUpdated(vault_);
    }

    function setOracle(address oracle_) external onlyOwner {
        if (oracle_ == address(0)) revert ZeroAddress();
        oracle = IPriceOracle(oracle_);
        emit OracleUpdated(oracle_);
    }

    function setPnlPool(address pnlPool_) external onlyOwner {
        if (pnlPool_ == address(0)) revert ZeroAddress();
        pnlPool = IPnlPool(pnlPool_);
        emit PnlPoolUpdated(pnlPool_);
    }

    function setProfitFeeBps(uint32 profitFeeBps_) external onlyOwner {
        if (profitFeeBps_ > 1_000) revert FeeTooHigh(); // max 10%
        profitFeeBps = profitFeeBps_;
        emit ProfitFeeBpsUpdated(profitFeeBps_);
    }

    function setVerifiers(EngineVerifiers calldata v) external onlyOwner {
        if (
            v.open == address(0) || v.close == address(0) || v.liquidate == address(0) || v.increase == address(0)
                || v.decrease == address(0) || v.health == address(0)
        ) revert ZeroAddress();
        openVerifier = IGroth16Verifier(v.open);
        closeVerifier = IGroth16Verifier(v.close);
        liquidateVerifier = IGroth16Verifier(v.liquidate);
        increaseVerifier = IGroth16Verifier(v.increase);
        decreaseVerifier = IGroth16Verifier(v.decrease);
        healthVerifier = IGroth16Verifier(v.health);
        emit VerifiersUpdated();
    }

    function setMaxPriceAge(uint256 maxPriceAge_) external onlyOwner {
        maxPriceAge = maxPriceAge_;
        emit MaxPriceAgeUpdated(maxPriceAge_);
    }

    function setMaxOpenAge(uint256 maxOpenAge_) external onlyOwner {
        maxOpenAge = maxOpenAge_;
        emit MaxOpenAgeUpdated(maxOpenAge_);
    }

    function setMaxLiqAge(uint256 maxLiqAge_) external onlyOwner {
        maxLiqAge = maxLiqAge_;
        emit MaxLiqAgeUpdated(maxLiqAge_);
    }

    function setMaxHealthAge(uint256 maxHealthAge_) external onlyOwner {
        maxHealthAge = maxHealthAge_;
        emit MaxHealthAgeUpdated(maxHealthAge_);
    }

    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedUpdated(paused_);
    }

    function setOrderModule(OrderKind kind, address module) external onlyOwner {
        if (module != address(0) && IOrderModule(module).kind() != kind) {
            revert OrderModuleKindMismatch();
        }
        orderModules[kind] = IOrderModule(module);
        emit OrderModuleUpdated(kind, module);
    }

    function executeOrder(OrderKind kind, Groth16Proof calldata proof, bytes calldata data) external {
        if (paused) revert Paused();
        IOrderModule module = orderModules[kind];
        if (address(module) == address(0)) revert OrderModuleUnset(kind);
        module.execute(msg.sender, proof, data);
    }

    function listMarket(uint32 marketId, bytes32 pythFeedId, uint32 maxLeverage, uint32 maintenanceMarginBps)
        external
        onlyOwner
    {
        if (maxLeverage == 0 || pythFeedId == bytes32(0)) revert MarketNotListed();
        Market storage m = markets[marketId];
        m.pythFeedId = pythFeedId;
        m.maxLeverage = maxLeverage;
        m.maintenanceMarginBps = maintenanceMarginBps;
        m.listed = true;
        if (m.epochDuration == 0) m.epochDuration = 1 hours;
        if (m.epochStart == 0) m.epochStart = block.timestamp;
        emit MarketListed(marketId, pythFeedId, maxLeverage, maintenanceMarginBps);
    }

    function setRiskParams(
        uint32 marketId,
        uint256 fundingFactorPerSecond,
        uint256 borrowFactorPerSecond,
        uint256 impactFactorBps,
        uint256 epochDuration
    ) external onlyOwner {
        Market storage m = _listed(marketId);
        m.fundingFactorPerSecond = fundingFactorPerSecond;
        m.borrowFactorPerSecond = borrowFactorPerSecond;
        m.impactFactorBps = impactFactorBps;
        if (epochDuration != 0) m.epochDuration = epochDuration;
        emit RiskParamsUpdated(marketId);
    }

    function delistMarket(uint32 marketId) external onlyOwner {
        markets[marketId].listed = false;
        emit MarketDelisted(marketId);
    }

    /// @notice Publish epoch aggregate OI (not a per-trade delta).
    function publishOi(uint32 marketId, uint256 longOi, uint256 shortOi) external onlyOwnerOrKeeper {
        Market storage m = _listed(marketId);
        m.longOi = longOi;
        m.shortOi = shortOi;
        emit OiPublished(marketId, longOi, shortOi);
    }

    function sealEpoch(uint32 marketId) external onlyOwnerOrKeeper {
        Market storage m = _listed(marketId);
        if (block.timestamp < m.epochStart + m.epochDuration) revert EpochNotReady();
        uint256 dt = block.timestamp - m.epochStart;
        (int256 payLong, int256 payShort) = PerpMath.fundingRatePerSecond(m.longOi, m.shortOi, m.fundingFactorPerSecond);
        m.fundingIndexLong += payLong * int256(dt);
        m.fundingIndexShort += payShort * int256(dt);
        m.epochStart = block.timestamp;
        emit EpochSealed(
            marketId,
            m.fundingIndexLong,
            m.fundingIndexShort,
            PerpMath.impactBpsFromSkew(m.longOi, m.shortOi, m.impactFactorBps)
        );
    }

    function scope() public view returns (uint256) {
        return uint256(uint160(address(this)));
    }

    function marketFeed(uint32 marketId) external view returns (bytes32) {
        return markets[marketId].pythFeedId;
    }

    function fundingIndexes(uint32 marketId) external view returns (int256 longIndex, int256 shortIndex) {
        Market storage m = markets[marketId];
        return (m.fundingIndexLong, m.fundingIndexShort);
    }

    function open(Groth16Proof calldata proof, OpenPublicInputs calldata inputs) external nonReentrant {
        if (paused) revert Paused();
        Market memory market = _listed(inputs.marketId);
        _requirePrice(market.pythFeedId, inputs.markPrice);
        if (inputs.positionCommitment == bytes32(0) || positions[inputs.positionCommitment]) {
            revert PositionTaken();
        }
        if (!vault.marginEnabled(inputs.collateralId)) revert CollateralDisabled();
        if (inputs.openedAt > block.timestamp || block.timestamp - inputs.openedAt > maxOpenAge) {
            revert StaleOpen();
        }

        uint256[] memory pub = PublicInputs.packOpen(
            inputs,
            market.maxLeverage,
            market.fundingIndexLong,
            PerpMath.impactBpsFromSkew(market.longOi, market.shortOi, market.impactFactorBps),
            scope()
        );
        if (!openVerifier.verifyProof(proof.a, proof.b, proof.c, pub)) revert InvalidProof();

        positions[inputs.positionCommitment] = true;
        vault.spendNote(inputs.noteNullifier, inputs.changeNoteCommitment, inputs.merkleRoot);
        emit PositionOpened(inputs.positionCommitment, inputs.noteNullifier, inputs.marketId);
    }

    function increase(Groth16Proof calldata proof, IncreasePublicInputs calldata inputs) external nonReentrant {
        if (paused) revert Paused();
        Market memory market = _listed(inputs.marketId);
        _requirePrice(market.pythFeedId, inputs.markPrice);
        _consumePosition(inputs.oldPositionCommitment, inputs.oldPositionNullifier);
        if (inputs.newPositionCommitment == bytes32(0) || positions[inputs.newPositionCommitment]) {
            revert PositionTaken();
        }
        if (!vault.marginEnabled(inputs.collateralId)) revert CollateralDisabled();

        uint256[] memory pub = PublicInputs.packIncrease(
            inputs,
            market.maxLeverage,
            market.fundingIndexLong,
            PerpMath.impactBpsFromSkew(market.longOi, market.shortOi, market.impactFactorBps),
            block.timestamp,
            scope()
        );
        if (!increaseVerifier.verifyProof(proof.a, proof.b, proof.c, pub)) revert InvalidProof();

        positions[inputs.newPositionCommitment] = true;
        vault.spendNote(inputs.extraNoteNullifier, inputs.changeNoteCommitment, inputs.merkleRoot);
        emit PositionIncreased(inputs.oldPositionCommitment, inputs.newPositionCommitment);
    }

    function decrease(Groth16Proof calldata proof, DecreasePublicInputs calldata inputs) external nonReentrant {
        if (paused) revert Paused();
        Market memory market = _listed(inputs.marketId);
        _requirePrice(market.pythFeedId, inputs.exitPrice);
        _consumePosition(inputs.oldPositionCommitment, inputs.oldPositionNullifier);

        uint256[] memory pub = PublicInputs.packDecrease(
            inputs,
            market.fundingIndexLong,
            PerpMath.impactBpsFromSkew(market.longOi, market.shortOi, market.impactFactorBps),
            block.timestamp,
            market.borrowFactorPerSecond,
            profitFeeBps,
            scope()
        );
        if (!decreaseVerifier.verifyProof(proof.a, proof.b, proof.c, pub)) revert InvalidProof();

        if (inputs.newPositionCommitment != bytes32(0)) {
            if (positions[inputs.newPositionCommitment]) revert PositionTaken();
            positions[inputs.newPositionCommitment] = true;
        }
        if (inputs.payoutNoteCommitment != bytes32(0)) {
            vault.insertNote(inputs.payoutNoteCommitment);
        }
        _payFee(inputs.collateralId, inputs.oldPositionCommitment, inputs.protocolFee);
        emit PositionDecreased(inputs.oldPositionCommitment, inputs.newPositionCommitment);
    }

    function close(Groth16Proof calldata proof, ClosePublicInputs calldata inputs) external nonReentrant {
        if (paused) revert Paused();
        Market memory market = _listed(inputs.marketId);
        _requirePrice(market.pythFeedId, inputs.exitPrice);
        _consumePosition(inputs.positionCommitment, inputs.positionNullifier);

        uint256[] memory pub = PublicInputs.packClose(
            inputs,
            market.fundingIndexLong,
            PerpMath.impactBpsFromSkew(market.longOi, market.shortOi, market.impactFactorBps),
            block.timestamp,
            market.borrowFactorPerSecond,
            profitFeeBps,
            scope()
        );
        if (!closeVerifier.verifyProof(proof.a, proof.b, proof.c, pub)) revert InvalidProof();

        if (inputs.payoutNoteCommitment != bytes32(0)) {
            vault.insertNote(inputs.payoutNoteCommitment);
        }
        _payFee(inputs.collateralId, inputs.positionCommitment, inputs.protocolFee);
        emit PositionClosed(inputs.positionCommitment, inputs.positionNullifier, inputs.payoutNoteCommitment);
    }

    function liquidate(Groth16Proof calldata proof, LiquidatePublicInputs calldata inputs) external nonReentrant {
        if (paused) revert Paused();
        _liquidate(proof, inputs);
    }

    function updateHealth(Groth16Proof calldata proof, HealthPublicInputs calldata inputs) external nonReentrant {
        if (paused) revert Paused();
        if (!positions[inputs.positionCommitment]) revert PositionUnknown();
        Market memory market = _listed(inputs.marketId);
        _requirePrice(market.pythFeedId, inputs.markPrice);

        uint256[] memory pub = PublicInputs.packHealth(
            inputs,
            market.maintenanceMarginBps,
            market.fundingIndexLong,
            PerpMath.impactBpsFromSkew(market.longOi, market.shortOi, market.impactFactorBps),
            block.timestamp,
            market.borrowFactorPerSecond,
            scope()
        );
        if (!healthVerifier.verifyProof(proof.a, proof.b, proof.c, pub)) revert InvalidProof();

        health[inputs.positionCommitment] = HealthState({
            commitment: inputs.healthCommitment,
            liquidatable: inputs.liquidatable != 0,
            updatedAt: uint64(block.timestamp)
        });
        emit HealthUpdated(inputs.positionCommitment, inputs.healthCommitment, inputs.liquidatable != 0);
    }

    /// @notice Liquidate using a posted health flag, or if health is stale (leftover = 0).
    function liquidateFromHealth(Groth16Proof calldata proof, LiquidatePublicInputs calldata inputs, bool requireFlag)
        external
        nonReentrant
    {
        if (paused) revert Paused();
        HealthState memory hs = health[inputs.positionCommitment];
        bool stale = hs.updatedAt == 0 || block.timestamp - hs.updatedAt > maxHealthAge;
        if (requireFlag && !hs.liquidatable && !stale) revert NotLiquidatable();
        if (!requireFlag && !stale) revert HealthFresh();
        _liquidate(proof, inputs);
        delete health[inputs.positionCommitment];
    }

    function _liquidate(Groth16Proof calldata proof, LiquidatePublicInputs calldata inputs) internal {
        Market memory market = _listed(inputs.marketId);
        _requirePrice(market.pythFeedId, inputs.exitPrice);
        if (inputs.closedAt > block.timestamp || block.timestamp - inputs.closedAt > maxLiqAge) {
            revert StaleLiquidation();
        }
        _consumePosition(inputs.positionCommitment, inputs.positionNullifier);

        uint256[] memory pub = PublicInputs.packLiquidate(
            inputs,
            market.maintenanceMarginBps,
            market.fundingIndexLong,
            PerpMath.impactBpsFromSkew(market.longOi, market.shortOi, market.impactFactorBps),
            inputs.closedAt,
            market.borrowFactorPerSecond,
            scope()
        );
        if (!liquidateVerifier.verifyProof(proof.a, proof.b, proof.c, pub)) revert InvalidProof();

        if (inputs.leftoverNoteCommitment != bytes32(0)) {
            vault.insertNote(inputs.leftoverNoteCommitment);
        }
        _seize(inputs.collateralId, inputs.positionCommitment, inputs.seizedAmount);
        emit PositionLiquidated(inputs.positionCommitment, inputs.positionNullifier, inputs.leftoverNoteCommitment);
    }

    function _payFee(uint32 collateralId, bytes32 position, uint256 amount) internal {
        if (amount == 0) return;
        if (address(pnlPool) == address(0)) revert PoolUnset();
        vault.payProtocol(collateralId, address(pnlPool), amount);
        pnlPool.receiveFee(amount);
        emit ProtocolFeePaid(position, amount);
    }

    function _seize(uint32 collateralId, bytes32 position, uint256 amount) internal {
        if (amount == 0) return;
        if (address(pnlPool) == address(0)) revert PoolUnset();
        vault.payProtocol(collateralId, address(pnlPool), amount);
        pnlPool.receiveSeized(amount);
        emit MarginSeized(position, amount);
    }

    function _listed(uint32 marketId) internal view returns (Market storage market) {
        market = markets[marketId];
        if (!market.listed) revert MarketNotListed();
    }

    function _requirePrice(bytes32 feedId, uint256 claimed) internal view {
        (uint256 price, uint256 publishTime) = oracle.getPrice(feedId);
        if (publishTime > block.timestamp || block.timestamp - publishTime > maxPriceAge) {
            revert StalePrice();
        }
        if (price != claimed) revert PriceMismatch();
    }

    function _consumePosition(bytes32 commitment, bytes32 nullifier) internal {
        if (commitment == bytes32(0) || !positions[commitment]) revert PositionUnknown();
        if (nullifier == bytes32(0) || nullifiers[nullifier]) revert NullifierUsed();
        positions[commitment] = false;
        nullifiers[nullifier] = true;
    }
}
