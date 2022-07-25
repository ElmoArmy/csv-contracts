// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

abstract contract CSVFeeCollector is Initializable, ContextUpgradeable {
    using FixedPointMathLib for uint256;
    // uint256 private constant PERIOD_LENGTH = 12 weeks;

    enum FreezeFactor {
        TIME,
        PRICE,
        NONE,
        BOTH
    }
    struct FixedFactor {
        FreezeFactor frozenFactor;
        uint256 time;
        uint256 price;
    }
    event Collected(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // uint256 private _vaultInitPrice;
    // uint256 private _vaultInitTime;
    // uint256 private _vaultExpiry;
    // address private _vaultSponsor;
    // uint256 private _lastPriceUpdate;

    // uint256[2] private _priceAppreciationCache;
    // uint256 private _avgPriceFactor;

    // mapping(address => FixedFactor) public fixedFactorsFor;

    // modifier onlySponsor() {
    //     require(_msgSender() == _vaultSponsor);
    //     _;
    // }
    // modifier onlyFreshPrice() {
    //     require(
    //         block.timestamp < _lastPriceUpdate + PERIOD_LENGTH ||
    //             block.timestamp > _vaultExpiry
    //     );
    //     _;
    // }

    function __CSVFeeCollector_init() internal virtual;

    function __CSVFeeCollector_init_unchained() internal virtual;

    function previewWithdrawFee(uint256 assets)
        public
        virtual
        returns (uint256)
    {
        // fixed for now, todo: implement _getTimeFactor() and _getPriceFactor();
        uint256 timeFactor = _getTimeFactor();
        uint256 priceFactor = _getPriceFactor();
        return _previewFeeInAssets(assets, timeFactor, priceFactor);
    }

    function previewRedeemFee(uint256 shares)
        public
        view
        virtual
        returns (uint256 FeeInShares);

    function maxWithdrawFee(uint256 assets)
        public
        view
        virtual
        returns (uint256 feeInAssets);

    function maxRedeemFee(uint256 shares)
        public
        view
        virtual
        returns (uint256 FeeInShares);

    function freezeFeeFor(address owner, FreezeFactor componentsToFreeze)
        public
        virtual
        returns (
            uint256 timeFactor,
            uint256 priceFactor,
            FreezeFactor status
        );

    function _previewFeeInAssets(
        uint256 shares,
        uint256 timeFactor,
        uint256 priceFactor
    ) internal virtual returns (uint256 feeInAssets) {
        return shares.mulWadUp(timeFactor).mulWadUp(priceFactor);
    }

    function _previewFeeInAssetsFor(address owner)
        internal
        virtual
        returns (uint256 feeInAssets);

    function _previewFeeInShares(
        uint256 shares,
        uint256 timeFactor,
        uint256 priceFactor
    ) internal view virtual returns (uint256 feeInShares);

    function _previewFeeInSharesFor(address owner)
        internal
        view
        virtual
        returns (uint256 feeInShares);

    function _collectWithdrawFor(address owner, uint256 assets)
        internal
        virtual
        returns (uint256 collectedShares);

    function _collectRedeemFor(address owner, uint256 shares)
        internal
        virtual
        returns (uint256 collectedAssets);

    function _getTimeFactor() internal virtual returns (uint256) {
        //TODO: implement basic strategy
        return 1 ether;
    }

    function _getPriceFactor() internal virtual returns (uint256) {
        //TODO: implement basic strategy
        return 1 ether;
    }

    /**
     * @dev empty reserved space
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[43] private __gap;
}
