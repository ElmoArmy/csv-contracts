// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC4626Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC20MetadataUpgradeable.sol";

contract CSVVault is ERC4626Upgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address asset_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC4626_init(IERC20MetadataUpgradeable(asset_));
    }
}
