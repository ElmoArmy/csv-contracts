// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC4626Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC20MetadataUpgradeable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {CSVVaultFees} from "./CSVVaultFees.sol";
import {CSVVaultDelegation} from "./CSVVaultDelegation.sol";

contract CSVVault is ERC4626Upgradeable, CSVVaultFees, CSVVaultDelegation {
    using FixedPointMathLib for uint256;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address asset_,
        uint256 startTime_,
        uint256 maturity_,
        uint256 scale_,
        address csvMain_,
        address csvWalletImplementation_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC4626_init(IERC20MetadataUpgradeable(asset_));
        __CSVVaultFees_init(startTime_, maturity_, scale_, csvMain_);
        __CSVVaultDelegation_init(csvWalletImplementation_);
    }

    function previewWithdraw(uint256 assets)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 feeFactor = previewFee(Discount.BOTH);
        uint256 feeInAssets = feeFactor >= 1 ether
            ? assets.mulWadUp(feeFactor)
            : assets.divWadUp(1 ether - feeFactor) - assets;

        return super.previewWithdraw(assets) + convertToShares(feeInAssets);
    }

    function maxWithdraw(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 maxAssets = super.maxWithdraw(owner);
        uint256 fee = maxFeeFor(owner).mulWadUp(maxAssets);
        return fee >= maxAssets ? 0 : maxAssets - fee;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(
            assets <= maxWithdraw(owner),
            "ERC4626: withdraw more than max"
        );
        uint256 receiverAssets = assets;
        uint256 receiverShares = convertToShares(receiverAssets);
        uint256 feeInAssets = assets.divWadUp(1 ether - maxFeeFor(owner)) -
            assets;
        uint256 feeInShares = convertToShares(feeInAssets);

        if (feeInAssets > 0) {
            _withdraw(_msgSender(), csvMain, owner, feeInAssets, feeInShares);
            emit CollectedFee(
                _msgSender(),
                receiver,
                owner,
                feeInAssets,
                feeInShares
            );
        }
        _withdraw(
            _msgSender(),
            receiver,
            owner,
            receiverAssets,
            receiverShares
        );

        return feeInShares + receiverShares;
    }

    function previewRedeem(uint256 shares)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 assets = super.previewRedeem(shares);
        uint256 fee = previewFee(Discount.BOTH).mulWadUp(assets);
        return fee > assets ? 0 : assets - fee;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        uint256 feeInShares = maxFeeFor(owner).mulWadUp(shares);
        uint256 feeInAssets = convertToAssets(feeInShares);
        uint256 receiverShares = shares - feeInShares;
        uint256 receiverAssets = convertToAssets(receiverShares);
        if (feeInShares > 0) {
            _withdraw(_msgSender(), csvMain, owner, feeInAssets, feeInShares);
            emit CollectedFee(
                _msgSender(),
                receiver,
                owner,
                feeInAssets,
                feeInShares
            );
        }
        _withdraw(
            _msgSender(),
            receiver,
            owner,
            receiverAssets,
            receiverShares
        );
        return receiverAssets;
    }
}
