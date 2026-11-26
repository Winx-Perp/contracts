// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkOracleAdapter} from "../src/oracle/ChainlinkOracleAdapter.sol";
import {PythOracleAdapter, IPyth} from "../src/oracle/PythOracleAdapter.sol";
import {MockPriceOracle} from "../src/oracle/MockPriceOracle.sol";

contract MockAggregator {
    int256 public answer;
    uint256 public updatedAt;
    uint8 public decimals_ = 8;

    function set(int256 answer_, uint256 updatedAt_, uint8 decimals__) external {
        answer = answer_;
        updatedAt = updatedAt_;
        decimals_ = decimals__;
    }

    function decimals() external view returns (uint8) {
        return decimals_;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}

contract MockPyth {
    mapping(bytes32 => IPyth.Price) public prices;

    function set(bytes32 id, int64 price, int32 expo, uint256 publishTime) external {
        prices[id] = IPyth.Price({price: price, conf: 0, expo: expo, publishTime: publishTime});
    }

    function getPriceUnsafe(bytes32 id) external view returns (IPyth.Price memory) {
        return prices[id];
    }
}

contract OracleTest is Test {
    bytes32 internal constant BTC_PYTH = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    bytes32 internal constant ETH_PYTH = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    function test_mockOracleBtcEth() public {
        MockPriceOracle oracle = new MockPriceOracle();
        oracle.setPrice(BTC_PYTH, 64_808e8, block.timestamp);
        oracle.setPrice(ETH_PYTH, 1_832e8, block.timestamp);
        (uint256 btc,) = oracle.getPrice(BTC_PYTH);
        (uint256 eth,) = oracle.getPrice(ETH_PYTH);
        assertEq(btc, 64_808e8);
        assertEq(eth, 1_832e8);
    }

    function test_chainlinkAdapterNormalizesTo1e8() public {
        MockAggregator agg = new MockAggregator();
        ChainlinkOracleAdapter oracle = new ChainlinkOracleAdapter();
        bytes32 id = oracle.feedIdOf(address(agg));

        agg.set(64_808_17000000, 1_700_000_000, 8);
        (uint256 px, uint256 t) = oracle.getPrice(id);
        assertEq(px, 64_808_17000000);
        assertEq(t, 1_700_000_000);

        agg.set(1_832_58664106, 1_700_000_001, 8);
        (px,) = oracle.getPrice(id);
        assertEq(px, 1_832_58664106);

        agg.set(99_999_944, 1_700_000_002, 8); // USDG ~ $1
        (px,) = oracle.getPrice(id);
        assertEq(px, 99_999_944);

        agg.set(183_258_664, 1_700_000_003, 6); // 6 dp → 1e8
        (px,) = oracle.getPrice(id);
        assertEq(px, 18_325_866_400);
    }

    function test_chainlinkRejectsBadAnswer() public {
        MockAggregator agg = new MockAggregator();
        ChainlinkOracleAdapter oracle = new ChainlinkOracleAdapter();
        bytes32 id = oracle.feedIdOf(address(agg));
        agg.set(0, block.timestamp, 8);
        vm.expectRevert(ChainlinkOracleAdapter.InvalidPrice.selector);
        oracle.getPrice(id);
        agg.set(-1, block.timestamp, 8);
        vm.expectRevert(ChainlinkOracleAdapter.InvalidPrice.selector);
        oracle.getPrice(id);
    }

    function test_pythAdapterExpoTo1e8() public {
        MockPyth pyth = new MockPyth();
        PythOracleAdapter oracle = new PythOracleAdapter(address(pyth));
        pyth.set(BTC_PYTH, 64_808_17000000, -8, 1_700_000_000);
        (uint256 btc, uint256 t) = oracle.getPrice(BTC_PYTH);
        assertEq(btc, 64_808_17000000);
        assertEq(t, 1_700_000_000);

        pyth.set(ETH_PYTH, 1_832_59, -2, 1_700_000_010); // $1832.59 at expo -2 → 1e8
        (uint256 eth,) = oracle.getPrice(ETH_PYTH);
        assertEq(eth, 1_832_59000000);
    }
}

/// Fork Robinhood mainnet (chain 4663) to read live Chainlink feeds.
/// `forge test --match-contract LiveChainlinkOracleTest --fork-url $ROBINHOOD_RPC_URL -vv`
contract LiveChainlinkOracleTest is Test {
    ChainlinkOracleAdapter internal oracle;

    address internal constant BTC = 0xa2c5184bF03d373Dc9dE4876eb4Bce595B460251;
    address internal constant ETH = 0x78F3556b67E17Df817D51Ef5a990cDaF09E8d3A9;
    address internal constant USDG = 0x61B7e5650328764B076A108EFF5fa7282a1B9aD2;
    address internal constant USDC = 0x9e6f4605992a899eE2999999F3Ec80C41F452546;
    address internal constant TSLA = 0x4A1166a659A55625345e9515b32adECea5547C38;
    address internal constant NVDA = 0x379EC4f7C378F34a1B47E4F3cbeBCbAC3E8E9F15;

    function setUp() public {
        if (block.chainid != 4663) {
            vm.skip(true);
            return;
        }
        oracle = new ChainlinkOracleAdapter();
    }

    function test_liveBtcEthStablesAndStocks() public {
        if (block.chainid != 4663) return;
        _assertUsd("BTC", BTC, 10_000e8, 500_000e8);
        _assertUsd("ETH", ETH, 100e8, 50_000e8);
        _assertUsd("USDG", USDG, 0.95e8, 1.05e8);
        _assertUsd("USDC", USDC, 0.95e8, 1.05e8);
        _assertUsd("TSLA", TSLA, 1e8, 10_000e8);
        _assertUsd("NVDA", NVDA, 1e8, 10_000e8);
    }

    function _assertUsd(string memory name, address feed, uint256 lo, uint256 hi) internal {
        (uint256 px, uint256 ts) = oracle.getPrice(oracle.feedIdOf(feed));
        emit log_named_string("asset", name);
        emit log_named_decimal_uint("usd_1e8", px, 8);
        emit log_named_uint("updatedAt", ts);
        assertGt(px, 0, name);
        assertGe(px, lo, name);
        assertLe(px, hi, name);
        assertGt(ts, 0, name);
        assertLe(block.timestamp - ts, 2 days, name);
    }
}
