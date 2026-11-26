// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Multisig} from "../src/admin/Multisig.sol";
import {Timelock} from "../src/admin/Timelock.sol";
import {PerpEngine} from "../src/PerpEngine.sol";
import {Vault} from "../src/Vault.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";
import {PythOracleAdapter} from "../src/oracle/PythOracleAdapter.sol";
import {ChainlinkOracleAdapter} from "../src/oracle/ChainlinkOracleAdapter.sol";
import {TriggerOrderModule} from "../src/orders/TriggerOrderModule.sol";
import {TwapOrderModule} from "../src/orders/TwapOrderModule.sol";
import {OrderKind} from "../src/orders/OrderTypes.sol";
import {EngineVerifiers} from "../src/lib/Types.sol";
import {MockVerifier} from "../src/verifiers/MockVerifier.sol";
import {USDW} from "../src/token/USDW.sol";
import {EthUsdwSwap} from "../src/token/EthUsdwSwap.sol";

/// Local / testnet deploy. Swap MockVerifier for generated Groth16 verifiers
/// and MockPriceOracle for PythOracleAdapter before production.
/// Do not broadcast until the user asks — construct via `runWithUsdw`.
contract Deploy {
    function run(address owner, address collateral) external returns (Vault vault, PerpEngine engine) {
        MockVerifier verifier = new MockVerifier();
        MockPriceOracle oracle = new MockPriceOracle();
        EngineVerifiers memory v = EngineVerifiers({
            open: address(verifier),
            close: address(verifier),
            liquidate: address(verifier),
            increase: address(verifier),
            decrease: address(verifier),
            health: address(verifier)
        });
        vault = new Vault(address(this), collateral, address(verifier), address(verifier), address(0));
        engine = new PerpEngine(address(this), address(vault), address(oracle), v);
        vault.setEngine(address(engine));
        _wireModules(engine);
        vault.transferOwnership(owner);
        engine.transferOwnership(owner);
    }

    function runWithPyth(address owner, address collateral, address pyth)
        external
        returns (Vault vault, PerpEngine engine)
    {
        MockVerifier verifier = new MockVerifier();
        PythOracleAdapter oracle = new PythOracleAdapter(pyth);
        EngineVerifiers memory v = EngineVerifiers({
            open: address(verifier),
            close: address(verifier),
            liquidate: address(verifier),
            increase: address(verifier),
            decrease: address(verifier),
            health: address(verifier)
        });
        vault = new Vault(address(this), collateral, address(verifier), address(verifier), address(0));
        engine = new PerpEngine(address(this), address(vault), address(oracle), v);
        vault.setEngine(address(engine));
        _wireModules(engine);
        vault.transferOwnership(owner);
        engine.transferOwnership(owner);
    }

    /// Robinhood Chain production oracle (Chainlink aggregators).
    function runWithChainlink(address owner, address collateral)
        external
        returns (Vault vault, PerpEngine engine, ChainlinkOracleAdapter oracle)
    {
        oracle = new ChainlinkOracleAdapter();
        MockVerifier verifier = new MockVerifier();
        EngineVerifiers memory v = EngineVerifiers({
            open: address(verifier),
            close: address(verifier),
            liquidate: address(verifier),
            increase: address(verifier),
            decrease: address(verifier),
            health: address(verifier)
        });
        vault = new Vault(address(this), collateral, address(verifier), address(verifier), address(0));
        engine = new PerpEngine(address(this), address(vault), address(oracle), v);
        vault.setEngine(address(engine));
        _wireModules(engine);
        vault.transferOwnership(owner);
        engine.transferOwnership(owner);
    }

    function runGoverned(address[] memory signers, uint256 threshold, uint256 delay, address collateral)
        external
        returns (Vault vault, PerpEngine engine, Multisig ms, Timelock lock_)
    {
        ms = new Multisig(signers, threshold);
        lock_ = new Timelock(address(ms), delay);
        (vault, engine) = this.run(address(lock_), collateral);
    }

    /// @notice USDW (1B to `admin`) + ETH→USDW swap + vault with USDW as primary
    /// collateral (id 1). Admin can `addCollateral` later.
    /// Admin later seeds `swap` with USDW (`usdw.transfer(swap, amount)`).
    /// Does not broadcast; call from a Foundry script when you are ready to deploy.
    function runWithUsdw(address admin, uint256 ethUsd1e8)
        external
        returns (USDW usdw, EthUsdwSwap swap, Vault vault, PerpEngine engine)
    {
        usdw = new USDW(admin);
        swap = new EthUsdwSwap(admin, address(usdw), ethUsd1e8);
        (vault, engine) = this.run(admin, address(usdw));
    }

    function _wireModules(PerpEngine engine) internal {
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
}
