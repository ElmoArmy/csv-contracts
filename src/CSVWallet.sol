// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Votes} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";

contract CSVWallet is Initializable, ContextUpgradeable, OwnableUpgradeable {
    ERC20Votes public immutable votingToken;

    constructor(ERC20Votes _votingToken) {
        votingToken = _votingToken;
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        _approveInfinite();
    }

    function delegateTo(address delegatee) public onlyOwner {
        votingToken.delegate(delegatee);
    }

    function _approveInfinite() internal virtual {
        votingToken.approve(_msgSender(), type(uint256).max);
    }
}
