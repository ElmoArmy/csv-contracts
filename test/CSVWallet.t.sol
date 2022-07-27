// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MockVotingToken} from "./mocks/MockVotingToken.sol";
import {PRBTest} from "prb-test/PRBTest.sol";
import {MinimalProxyFactory} from "solidstate-solidity/factory/MinimalProxyFactory.sol";
import {CSVWallet} from "../src/CSVWallet.sol";

contract CSVWalletTest is PRBTest, MinimalProxyFactory {
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    CSVWallet wallet;
    CSVWallet proxyWallet;
    MockVotingToken token;

    function setUp() public {
        token = new MockVotingToken();
        wallet = new CSVWallet(token);
        proxyWallet = CSVWallet(_deployMinimalProxy(address(wallet)));
        proxyWallet.initialize();
    }

    function testWalletCannotInitialize() public {
        vm.expectRevert("Initializable: contract is already initialized");
        wallet.initialize();
    }

    function testProxyWasInitialized() public {
        assertEq(proxyWallet.owner(), address(this));
    }

    function testProxyInitializableOnce() public {
        vm.expectRevert("Initializable: contract is already initialized");
        proxyWallet.initialize();
    }

    function testWalletCannotDelegate() public {
        vm.expectRevert("Ownable: caller is not the owner");
        address delegatee = address(0x1234567890123456789012345678901234567890);
        wallet.delegateTo(delegatee);
    }

    function testProxyDelegation() public {
        address delegator = address(proxyWallet);
        address currentDelegatee = address(0);
        address delegatee = address(0x1234567890123456789012345678901234567890);

        vm.expectEmit(true, true, true, false);
        emit DelegateChanged(delegator, currentDelegatee, delegatee);
        proxyWallet.delegateTo(delegatee);
    }

    function testProxyInitializesAllowanceToOwner() public {
        address owner = address(proxyWallet);
        address spender = address(this);
        assertEq(token.allowance(owner, spender), type(uint256).max);
    }
}
