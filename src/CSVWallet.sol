// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20Votes} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";

contract CSVWallet is Initializable, Ownable {
    ERC20Votes immutable _token;

    constructor(ERC20Votes votingToken) {
        _token = votingToken;
        // @dev Disables base implementation.
        _transferOwnership(address(0xdeadbeef));
        _disableInitializers();
    }

    function initialize(address vault) public initializer {
        _transferOwnership(vault);
        _approveMaxTransfers(vault);
    }

    function delegateTo(address delegatee) public onlyOwner {
        _token.delegate(delegatee);
    }

    function _approveMaxTransfers(address vault) internal {
        _token.approve(vault, type(uint256).max);
    }
}
