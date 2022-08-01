// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import {MinimalProxyFactory} from "solidstate-solidity/factory/MinimalProxyFactory.sol";
import {CSVWallet} from "./CSVWallet.sol";

abstract contract CSVVaultDelegation is
    Initializable,
    ContextUpgradeable,
    MinimalProxyFactory
{
    address public walletImplementation;
    uint256 public totalDelegated;
    mapping(address => CSVWallet) public delegated;

    /*//////////////////////////////////////////////////////////////
                               INITIALIZERS
    //////////////////////////////////////////////////////////////*/
    function __CSVVaultDelegation_init(address implementation_)
        internal
        virtual
        onlyInitializing
    {
        __CSVVaultDelegation_init_unchained(implementation_);
    }

    function __CSVVaultDelegation_init_unchained(address implementation_)
        internal
        virtual
        onlyInitializing
    {
        walletImplementation = implementation_;
    }

    function _delegateTo(address delegatee) internal {
        CSVWallet wallet = delegated[_msgSender()];
        if (address(wallet) == address(0)) {
            // create a new wallet and store in delegated
            wallet = _createProxy();
            delegated[_msgSender()] = wallet;
        }
        wallet.delegateTo(delegatee);
    }

    function _createProxy() private returns (CSVWallet) {
        CSVWallet proxy = CSVWallet(
            _deployMinimalProxy(address(walletImplementation))
        );
        // @dev failing to initialize the proxy would allow for account takeover
        proxy.initialize();
        return proxy;
    }
}
