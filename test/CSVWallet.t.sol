// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {PRBTest} from "prb-test/PRBTest.sol";
import {MinimalProxyFactory} from "solidstate-solidity/factory/MinimalProxyFactory.sol";
import {CSVWallet} from "../src/CSVWallet.sol";
import {Votes} from "openzeppelin-contracts/governance/utils/Votes.sol";
import {EIP712} from "openzeppelin-contracts/utils/cryptography/draft-EIP712.sol";

contract MockVoteToken is Votes {
    constructor() EIP712(string("MOCK"), string("0xdead")) {}

    function _getVotingUnits(address account)
        internal
        pure
        override
        returns (uint256)
    {
        require(account != address(0x0), "address 0 doesn't have voting units");
        return 1 ether;
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
    MockVoteToken token;
    // @notice In a standard (non-proxied) deployment, the owner of the contract is 0xdeadbeef.
    address constant DEFAULT_OWNER = address(0xdeadbeef);

    function setUp() public {
        wallet = new CSVWallet();
        proxyWallet = CSVWallet(_deployMinimalProxy(address(wallet)));
        token = new MockVoteToken();
    }

    function testDifferentOwners() public {
        assertNotEq(wallet.owner(), proxyWallet.owner());
    }

    function testWalletCannotInitialize() public {
        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        wallet.initialize(address(this));
    }

    function testProxyCanInitialize() public {
        proxyWallet.initialize(address(this));
        assertEq(proxyWallet.owner(), address(this));
    }

    function testProxyInitializableOnce() public {
        proxyWallet.initialize(address(this));
        vm.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        proxyWallet.initialize(address(this));
    }

    function testWalletCannotDelegate() public {
        address delegatee = address(0x1234567890123456789012345678901234567890);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        wallet.delegateERC20(token, delegatee);
    }

    function testProxyDelegation() public {
        address delegator = address(proxyWallet);
        address currentDelegatee = address(0);
        address delegatee = address(0x1234567890123456789012345678901234567890);

        vm.expectEmit(true, true, true, false);
        emit DelegateChanged(delegator, currentDelegatee, delegatee);
        proxyWallet.initialize(address(this));
        proxyWallet.delegateERC20(token, delegatee);
    }
}
