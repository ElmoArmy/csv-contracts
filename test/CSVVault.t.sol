// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {PRBTest} from "prb-test/PRBTest.sol";
import {CSVVault} from "../src/CSVVault.sol";
import {CSVWallet} from "../src/CSVWallet.sol";
import {MockVotingToken} from "./mocks/MockVotingToken.sol";
import {MinimalProxyFactory} from "solidstate-solidity/factory/MinimalProxyFactory.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract CSVVaultTest is PRBTest, MinimalProxyFactory {
    using FixedPointMathLib for uint256;

    event CollectedFee(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    struct vaultInitializeParams {
        string name;
        string symbol;
        address asset;
        uint256 startTime;
        uint256 maturity;
        uint256 scale;
        address sponsor;
        address walletImplementation;
    }
    MockVotingToken asset;
    vaultInitializeParams defaultParams;
    CSVVault vault;
    CSVVault proxyVault;
    CSVWallet walletBaseImplementation;

    // @dev helper function to mint asset tokens
    function dealToken(address to, uint256 amount) internal returns (uint256) {
        asset.mockMint(to, amount);
        return amount;
    }

    function setUp() public {
        asset = new MockVotingToken();
        vault = new CSVVault();
        walletBaseImplementation = new CSVWallet(asset);

        defaultParams = vaultInitializeParams(
            "CSVVault",
            "CSV",
            address(asset),
            block.timestamp,
            block.timestamp + (4 weeks * 36),
            2 ether,
            address(this),
            address(walletBaseImplementation)
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
            defaultParams.sponsor,
            defaultParams.walletImplementation
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
            defaultParams.sponsor,
            defaultParams.walletImplementation
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
        assertEq(
            proxyVault.walletImplementation(),
            defaultParams.walletImplementation
        );
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

    function testProxyCollectsFee() public {
        // setup actors
        address sponsor = address(this);
        address claimantAlice = address(0xffff);
        address claimantBob = address(0xeeee);
        //label actors
        vm.label(claimantAlice, "Alice");
        vm.label(claimantBob, "Bob");
        vm.label(sponsor, "sponsor");

        // sponsor actions
        uint256 depositAmount = dealToken(sponsor, 100 ether);
        asset.approve(address(proxyVault), type(uint256).max);

        proxyVault.deposit(depositAmount / 2, claimantAlice);
        proxyVault.deposit(depositAmount / 2, claimantBob);

        // fast forward to maturity - 12 weeks, most assets available to withdraw;
        vm.warp(
            block.timestamp +
                (defaultParams.maturity - block.timestamp - 12 weeks)
        );
        // Alice redeems all shares.
        vm.startPrank(claimantAlice);

        // @ dev max redeem does not account for fees the way maxWitdraw does.
        // A claimant may redeem all shares, but they will still be charged their individual fee.
        uint256 allSharesAlice = proxyVault.maxRedeem(claimantAlice);
        // preview redeem does not take into account frozen fees, so it may be inaccurate.
        uint256 expectedAssetsToWithdraw = proxyVault.maxWithdraw(
            claimantAlice
        );

        // expect CollectedFee event.
        vm.expectEmit(true, true, true, false, address(proxyVault));
        emit CollectedFee(
            claimantAlice,
            claimantAlice,
            claimantAlice,
            0 ether, // not checked
            0 ether //  not checked
        );
        uint256 assetsClaimed = proxyVault.redeem(
            allSharesAlice,
            claimantAlice,
            claimantAlice
        );
        assertEq(assetsClaimed, expectedAssetsToWithdraw);
        vm.stopPrank();
        uint256 sponsorBalance = asset.balanceOf(sponsor);
        uint256 aliceBalance = asset.balanceOf(claimantAlice);

        //balance of Alice + balance of Sponsor should equal balance of Vault after redemption.
        assertEq(sponsorBalance + aliceBalance, proxyVault.totalAssets());

        // skip till vault expiry
        vm.warp(block.timestamp + (12 weeks));

        vm.startPrank(claimantBob);
        uint256 allSharesBob = proxyVault.maxRedeem(claimantBob);
        uint256 expectedAssetsToWithdrawBob = proxyVault.maxWithdraw(
            claimantBob
        );
        uint256 assetsClaimedBob = proxyVault.redeem(
            allSharesBob,
            claimantBob,
            claimantBob
        );
        assertEq(assetsClaimedBob, expectedAssetsToWithdrawBob);
        vm.stopPrank();

        // balance for sponsor should stay the same.
        assertEq(sponsorBalance, asset.balanceOf(sponsor));

        assertEq(sponsorBalance + aliceBalance, asset.balanceOf(claimantBob));
    }

    function testProxyDelegation() public {
        // setup actors
        address sponsor = address(this);
        address claimantAlice = address(0xffff);
        //label actors
        vm.label(claimantAlice, "Alice");
        vm.label(sponsor, "sponsor");

        // sponsor actions
        uint256 depositAmount = dealToken(sponsor, 100 ether);
        asset.approve(address(proxyVault), type(uint256).max);

        proxyVault.deposit(depositAmount, claimantAlice);

        vm.startPrank(claimantAlice);
        // allice should not have any assets available to delegate.
        assertEq(proxyVault.delegateCurrentClaim(claimantAlice), 0 ether);

        // fast forward to maturity - 12 weeks, most assets available to withdraw;
        vm.warp(
            block.timestamp +
                (defaultParams.maturity - block.timestamp - 12 weeks)
        );
        uint256 avaiableToWithdraw = proxyVault.maxWithdraw(claimantAlice);
        assertGt(avaiableToWithdraw, 0 ether);
        assertEq(
            proxyVault.delegateCurrentClaim(claimantAlice),
            avaiableToWithdraw
        );
        // trying to delegate again should result in no more delegation.
        assertEq(proxyVault.delegateCurrentClaim(claimantAlice), 0 ether);
        // should still be able to withdraw the same amount.
        assertEq(proxyVault.maxWithdraw(claimantAlice), avaiableToWithdraw);

        assertEq(proxyVault.totalDelegated(), avaiableToWithdraw);
        // vault should have more assets than total delegated at this time.
        assertGt(proxyVault.totalAssets(), avaiableToWithdraw);

        // withdraw half of available assets.
        proxyVault.withdraw(
            avaiableToWithdraw / 2,
            claimantAlice,
            claimantAlice
        );
        // after withdrawing any portion, all assets are undelegated
        assertEq(proxyVault.totalDelegated(), 0 ether);
        assertGt(proxyVault.totalAssets(), avaiableToWithdraw / 2);

        // alice delegates again after withdrawing.
        assertEq(
            proxyVault.delegateCurrentClaim(claimantAlice),
            avaiableToWithdraw / 2
        );
        
    }
}
