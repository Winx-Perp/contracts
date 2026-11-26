// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {USDW} from "../src/token/USDW.sol";
import {EthUsdwSwap} from "../src/token/EthUsdwSwap.sol";
import {Vault} from "../src/Vault.sol";
import {MockVerifier} from "../src/verifiers/MockVerifier.sol";
import {Groth16Proof, ShieldPublicInputs} from "../src/lib/Types.sol";
import {MockERC20} from "./MockERC20.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {PerpEngine} from "../src/PerpEngine.sol";

contract USDWTest is Test {
    uint256 internal constant ETH_USD = 2_000e8;
    address internal admin = address(0xA0);
    address internal tester = address(0xB0);

    USDW internal usdw;
    EthUsdwSwap internal swapper;

    function setUp() public {
        usdw = new USDW(admin);
        swapper = new EthUsdwSwap(admin, address(usdw), ETH_USD);
        vm.prank(admin);
        usdw.transfer(address(swapper), 10_000_000e6);
    }

    function test_mintsOneBillionToAdmin() public view {
        assertEq(usdw.decimals(), 6);
        assertEq(usdw.symbol(), "USDW");
        assertEq(usdw.name(), "USDW");
        assertEq(usdw.totalSupply(), 1_000_000_000e6);
        assertEq(usdw.balanceOf(admin), 1_000_000_000e6 - 10_000_000e6);
        assertEq(usdw.balanceOf(admin) + usdw.balanceOf(address(swapper)), usdw.totalSupply());
    }

    function test_swapEthForUsdwAtOneDollar() public {
        vm.deal(tester, 1 ether);
        vm.prank(tester);
        uint256 out = swapper.swap{value: 1 ether}();
        // 1 ETH * $2000 = 2000 USDW (6 dp)
        assertEq(out, 2_000e6);
        assertEq(usdw.balanceOf(tester), 2_000e6);
        assertEq(address(swapper).balance, 1 ether);
    }

    function test_receiveEthSwaps() public {
        vm.deal(tester, 0.5 ether);
        vm.prank(tester);
        (bool ok,) = address(swapper).call{value: 0.5 ether}("");
        assertTrue(ok);
        assertEq(usdw.balanceOf(tester), 1_000e6);
    }

    function test_quoteMatchesSwap() public view {
        assertEq(swapper.quote(1 ether), 2_000e6);
        assertEq(swapper.quote(1e15), 2e6); // 0.001 ETH → 2 USDW
    }

    function test_adminWithdrawsEth() public {
        vm.deal(tester, 1 ether);
        vm.prank(tester);
        swapper.swap{value: 1 ether}();

        vm.prank(admin);
        swapper.withdrawEth(admin, 1 ether);
        assertEq(admin.balance, 1 ether);
    }

    function test_vaultOnlyAcceptsUsdw() public {
        MockVerifier verifier = new MockVerifier();
        Vault vault = new Vault(admin, address(usdw), address(verifier), address(verifier), address(0));

        vm.prank(admin);
        usdw.transfer(tester, 1_000e6);
        vm.prank(tester);
        usdw.approve(address(vault), type(uint256).max);

        Groth16Proof memory proof;
        vm.prank(tester);
        vault.shield(proof, ShieldPublicInputs({noteCommitment: keccak256("n"), collateralId: 1, amount: 500e6}));
        assertEq(usdw.balanceOf(address(vault)), 500e6);

        MockERC20 other = new MockERC20();
        other.mint(tester, 1_000e6);
        vm.prank(tester);
        other.approve(address(vault), type(uint256).max);
        // Vault pulls USDW, not the other token.
        assertEq(other.balanceOf(address(vault)), 0);
        assertEq(address(vault.token()), address(usdw));
        assertTrue(vault.marginEnabled(1));
    }

    function test_adminAddsSecondCollateral() public {
        MockVerifier verifier = new MockVerifier();
        Vault vault = new Vault(admin, address(usdw), address(verifier), address(verifier), address(0));
        MockERC20 usdc = new MockERC20();
        vm.prank(admin);
        vault.addCollateral(2, address(usdc), 6, true);

        usdc.mint(tester, 250e6);
        vm.prank(tester);
        usdc.approve(address(vault), type(uint256).max);

        Groth16Proof memory proof;
        vm.prank(tester);
        vault.shield(proof, ShieldPublicInputs({noteCommitment: keccak256("n2"), collateralId: 2, amount: 250e6}));
        assertEq(usdc.balanceOf(address(vault)), 250e6);
        assertEq(usdw.balanceOf(address(vault)), 0);
        assertTrue(vault.marginEnabled(2));
    }

    function test_cannotDisablePrimary() public {
        MockVerifier verifier = new MockVerifier();
        Vault vault = new Vault(admin, address(usdw), address(verifier), address(verifier), address(0));
        vm.prank(admin);
        vm.expectRevert(Vault.BadCollateral.selector);
        vault.setCollateral(1, false, true);
    }

    function test_permit() public {
        uint256 pk = 0xA11CE;
        address owner = vm.addr(pk);
        vm.prank(admin);
        usdw.transfer(owner, 100e6);

        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                usdw.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(usdw.PERMIT_TYPEHASH(), owner, tester, 40e6, uint256(0), deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        usdw.permit(owner, tester, 40e6, deadline, v, r, s);
        assertEq(usdw.allowance(owner, tester), 40e6);
    }

    function test_deployWiresVaultToUsdw() public {
        Deploy d = new Deploy();
        address owner = address(this);
        (USDW token, EthUsdwSwap s, Vault vault, PerpEngine engine) = d.runWithUsdw(owner, ETH_USD);
        assertEq(address(vault.token()), address(token));
        assertEq(token.balanceOf(owner), token.totalSupply());
        assertEq(address(s.usdw()), address(token));
        assertEq(address(engine.vault()), address(vault));
    }
}
