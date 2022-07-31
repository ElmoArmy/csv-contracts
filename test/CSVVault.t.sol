// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {PRBTest} from "prb-test/PRBTest.sol";
import {CSVVault} from "../src/CSVVault.sol";
import {MockVotingToken} from "./mocks/MockVotingToken.sol";
import {MinimalProxyFactory} from "solidstate-solidity/factory/MinimalProxyFactory.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract CSVVaultTest is PRBTest, MinimalProxyFactory {
    using FixedPointMathLib for uint256;

    struct vaultInitializeParams {
        string name;
        string symbol;
        address asset;
        uint256 startTime;
        uint256 maturity;
        uint256 scale;
        address sponsor;
    }
    MockVotingToken asset;
    vaultInitializeParams defaultParams;
    CSVVault vault;
    CSVVault proxyVault;

    // @dev helper function to mint asset tokens
    function dealToken(address to, uint256 amount) internal returns (uint256) {
        asset.mockMint(to, amount);
        return amount;
    }

    function setUp() public {
        asset = new MockVotingToken();
        vault = new CSVVault();
        defaultParams = vaultInitializeParams(
            "CSVVault",
            "CSV",
            address(asset),
            block.timestamp,
            block.timestamp + (4 weeks * 36),
            2 ether,
            address(this)
        );
        proxyVault = CSVVault(_deployMinimalProxy(address(vault)));
        vm.label(address(proxyVault), "proxyCSVVault");
        proxyVault.initialize(
            defaultParams.name,
            defaultParams.symbol,
            defaultParams.asset,
            defaultParams.startTime,
            defaultParams.maturity,
            defaultParams.scale,
            defaultParams.sponsor
        );
    }

    function testVaultCannotInitialize() public {
        vm.expectRevert("Initializable: contract is already initialized");
        vault.initialize(
            defaultParams.name,
            defaultParams.symbol,
            defaultParams.asset,
            defaultParams.startTime,
            defaultParams.maturity,
            defaultParams.scale,
            defaultParams.sponsor
        );
    }

    function testVaultCannotDeposit() public {
        uint256 depositAmount = 1 ether;
        address receiver = address(this);
        asset.mockMint(receiver, depositAmount);
        asset.approve(address(vault), type(uint256).max);
        // reverts due to asset not being initialized;
        vm.expectRevert();
        vault.deposit(depositAmount, receiver);
        assertEq(vault.asset(), address(0));
    }

    function testVaultwasNotInitialized() public {
        assertEq(vault.name(), "");
        assertEq(vault.maturity(), 0);
        assertEq(vault.asset(), address(0));
    }

    function testProxyVaultwasInitialized() public {
        assertEq(proxyVault.name(), defaultParams.name);
        assertEq(proxyVault.symbol(), defaultParams.symbol);
        assertEq(proxyVault.asset(), defaultParams.asset);
        assertEq(proxyVault.maturity(), defaultParams.maturity);
    }

    function testProxyTimeDiscount(uint256 warp) public {
        vm.assume(warp > 0 && warp <= type(uint256).max - block.timestamp);
        uint256 depositAmount = 1 ether;
        address receiver = address(this);
        uint256 expectedFee = uint256(1 ether).mulWadUp(proxyVault.scale());
        // mint asset to receiver and max approve transfers to the vault;
        asset.mockMint(receiver, depositAmount);
        asset.approve(address(proxyVault), type(uint256).max);
        proxyVault.deposit(depositAmount, receiver);
        // deposit was successful
        assertEq(proxyVault.totalAssets(), depositAmount);
        // before time warp, the vault is charging 100% of the deposit
        assertEq(proxyVault.maxFeeFor(receiver), expectedFee);
        vm.warp(block.timestamp + warp);
        // the vault is charging less fees than before time warp
        assertLt(proxyVault.maxFeeFor(receiver), expectedFee);
    }

    function testProxyTimeDiscount() public {
        address receiver = address(this);
        uint256 quarterOfRemainingTime = (defaultParams.maturity -
            block.timestamp) / 4;
        uint256 expectedDifference = uint256(.25 ether).mulWadUp(
            proxyVault.scale()
        );
        uint256 beforeWarpFee = proxyVault.maxFeeFor(receiver);

        // fast forward nine months;
        vm.warp(block.timestamp + quarterOfRemainingTime);
        uint256 afterWarpFee = proxyVault.maxFeeFor(receiver);

        // asserts that after time warp, the vault is charging less fees than before time warp
        assertEq(beforeWarpFee - afterWarpFee, expectedDifference);
    }

    function testProxyWithdraw() public {
        address claimant = address(0xffff);
        vm.label(claimant, "claimant");

        uint256 depositAmount = dealToken(address(this), 100 ether);
        asset.approve(address(proxyVault), type(uint256).max);
        proxyVault.deposit(depositAmount, claimant);

        // rest of calls are performed as claimant.
        vm.startPrank(claimant);
        // to withdraw all assets should require more than total shares.
        assertGt(
            proxyVault.previewWithdraw(proxyVault.totalAssets()),
            proxyVault.balanceOf(claimant)
        );
        // skip ahead to maturity - 12 weeks, most assets available to withdraw;
        vm.warp(
            block.timestamp +
                (defaultParams.maturity - block.timestamp - 12 weeks)
        );

        assertEq(
            proxyVault.previewWithdraw(proxyVault.maxWithdraw(claimant)),
            proxyVault.withdraw(
                proxyVault.maxWithdraw(claimant),
                claimant,
                claimant
            )
        );
        // skip ahead to maturity, all assets available to withdraw;
        vm.warp(block.timestamp + (12 weeks));
        assertEq(
            proxyVault.previewWithdraw(proxyVault.maxWithdraw(claimant)),
            proxyVault.withdraw(
                proxyVault.maxWithdraw(claimant),
                claimant,
                claimant
            )
        );
    }
}
