// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {PRBTest} from "prb-test/PRBTest.sol";
import {MinimalProxyFactory} from "solidstate-solidity/factory/MinimalProxyFactory.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC20Votes} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
import {CSVWallet} from "../src/CSVWallet.sol";

contract MockToken is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("MockToken", "MTK") ERC20Permit("MockToken") {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}

contract CSVWalletTest is PRBTest, MinimalProxyFactory {
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    CSVWallet wallet;
    CSVWallet proxyWallet;
    MockToken token;

    function setUp() public {
        token = new MockToken();
        wallet = new CSVWallet(token);
        proxyWallet = CSVWallet(_deployMinimalProxy(address(wallet)));
    }

    function testDifferentOwners() public {
        assertNotEq(wallet.owner(), proxyWallet.owner());
    }

    function testWalletCannotInitialize() public {
        vm.expectRevert("Initializable: contract is already initialized");
        wallet.initialize(address(this));
    }

    function testProxyCanInitialize() public {
        proxyWallet.initialize(address(this));
        assertEq(proxyWallet.owner(), address(this));
    }

    function testProxyInitializableOnce() public {
        proxyWallet.initialize(address(this));
        vm.expectRevert("Initializable: contract is already initialized");
        proxyWallet.initialize(address(this));
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
        proxyWallet.initialize(address(this));
        proxyWallet.delegateTo(delegatee);
    }

    function testProxyInitializesAllowanceToOwner() public {
        address owner = address(proxyWallet);
        address spender = address(this);
        proxyWallet.initialize(spender);
        assertEq(token.allowance(owner, spender), type(uint256).max);
    }
}
