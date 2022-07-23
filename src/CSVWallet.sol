// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IVotes} from "openzeppelin-contracts/governance/utils/IVotes.sol";

contract CSVWallet is Initializable, Ownable {
    address private constant DEFAULT_OWNER = address(0xdeadbeef);

    constructor() {
        _transferOwnership(DEFAULT_OWNER);
        _disableInitializers();
    }

    function initialize(address vault) public initializer {
        _transferOwnership(vault);
    }

    function delegateERC20(IVotes token, address delegatee) external onlyOwner {
        token.delegate(delegatee);
    }
}
