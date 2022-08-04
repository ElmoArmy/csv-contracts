// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {CSVVaultFactory} from "./CSVVaultFactory.sol";

abstract contract CSVVaultFees is Initializable, ContextUpgradeable {
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollectedFee(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                             STORAGE
    //////////////////////////////////////////////////////////////*/
    enum Discount {
        NONE,
        TIME,
        PRICE,
        BOTH
    }
    struct FrozenDiscount {
        Discount frozen;
        uint256 time;
        uint256 price;
    }
    mapping(address => FrozenDiscount) public frozenDiscountFor;

    uint256 internal constant ACCRUAL_RATE = 12 seconds;
    uint256 internal constant DEFAULT_FEE = 1 ether;
    uint256 public joinTime;
    uint256 public maturity;
    uint256 public scale;
    CSVVaultFactory public csvFactory;

    modifier onlyFactory() {
        require(_msgSender() == address(csvFactory));
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZERS
    //////////////////////////////////////////////////////////////*/
    function __CSVVaultFees_init(
        uint256 joinTime_,
        uint256 maturity_,
        uint256 scale_,
        address csvFactory_
    ) internal virtual onlyInitializing {
        __CSVVaultFees_init_unchained(
            joinTime_,
            maturity_,
            scale_,
            csvFactory_
        );
    }

    function __CSVVaultFees_init_unchained(
        uint256 joinTime_,
        uint256 maturity_,
        uint256 scale_,
        address csvFactory_
    ) internal virtual onlyInitializing {
        joinTime = joinTime_;
        maturity = maturity_;
        scale = scale_;
        csvFactory = CSVVaultFactory(csvFactory_);
    }

    /*//////////////////////////////////////////////////////////////
                        Fee Calculation and Freeze Logic
    //////////////////////////////////////////////////////////////*/

    function previewFee(Discount applyDiscount)
        public
        view
        virtual
        returns (uint256)
    {
        // Order in what will most likely be the shorter circuit when calling on chain.
        // Expecting more calls with Discount.TIME for delegations, followed by Dicount.BOTH in withdraws/redeems.
        uint256 timeDiscount = applyDiscount == Discount.TIME ||
            applyDiscount == Discount.BOTH
            ? _timeDiscount(
                block.timestamp,
                joinTime,
                maturity,
                scale,
                ACCRUAL_RATE
            )
            : DEFAULT_FEE;

        uint256 priceDiscount = applyDiscount == Discount.BOTH ||
            applyDiscount == Discount.PRICE
            ? _priceDiscount()
            : DEFAULT_FEE;

        return _applyFee(timeDiscount, priceDiscount);
    }

    function getfrozenDiscountFor(address owner_)
        public
        view
        virtual
        returns (FrozenDiscount memory)
    {
        FrozenDiscount memory frozenDiscount = frozenDiscountFor[owner_];
        return frozenDiscount;
    }

    function maxFeeFor(address owner) public view virtual returns (uint256) {
        FrozenDiscount memory userDiscount = frozenDiscountFor[owner];
        if (userDiscount.frozen == Discount.NONE) {
            // owner has no frozen discount, apply both discounts
            return previewFee(Discount.BOTH);
        } else if (userDiscount.frozen == Discount.BOTH) {
            // owner has both discounts frozen, apply only user specific fees
            return _applyFee(userDiscount.price, userDiscount.time);
        } else if (userDiscount.frozen == Discount.TIME) {
            // owner has a frozen time discount, apply only price discount
            return _applyFee(userDiscount.time, previewFee(Discount.PRICE));
        } else if (userDiscount.frozen == Discount.PRICE) {
            // owner has a frozen price discount, apply only time discount
            return _applyFee(previewFee(Discount.TIME), userDiscount.price);
        } else {
            // discount cases are exhausted
            // in the event an error was made, apply no discount for this user.
            return previewFee(Discount.NONE);
        }
    }

    function freezeFeeFor(address owner, Discount discount)
        public
        virtual
        onlyFactory
    {
        if (discount == Discount.NONE) {
            // delete any frozen discount for this user
            delete frozenDiscountFor[owner];
        } else {
            frozenDiscountFor[owner] = FrozenDiscount(
                discount,
                discount == Discount.TIME || discount == Discount.BOTH
                    ? previewFee(Discount.TIME)
                    : 0,
                discount == Discount.PRICE || discount == Discount.BOTH
                    ? previewFee(Discount.PRICE)
                    : 0
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                               Internal
    //////////////////////////////////////////////////////////////*/

    function _applyFee(uint256 timeFactor, uint256 priceFactor)
        internal
        pure
        virtual
        returns (uint256)
    {
        return timeFactor.mulWadUp(priceFactor);
    }

    function _timeDiscount(
        uint256 currentTime,
        uint256 startTime,
        uint256 maturityTime,
        uint256 scalingFactor,
        uint256 accrualRate
    ) internal pure virtual returns (uint256) {
        if (currentTime >= maturityTime || startTime >= maturityTime) return 0;
        require(startTime <= currentTime, "invalid joinTime");
        unchecked {
            uint256 total_periods_scaled = (maturityTime - startTime).mulDivUp(
                scalingFactor,
                accrualRate
            );

            uint256 elapsed_periods_scaled = (currentTime - startTime).mulDivUp(
                scalingFactor,
                accrualRate
            );
            if (elapsed_periods_scaled >= total_periods_scaled) {
                return 0;
            }
            return
                (total_periods_scaled - elapsed_periods_scaled).mulDivUp(
                    scalingFactor,
                    total_periods_scaled
                );
        }
    }

    function _priceDiscount() internal view virtual returns (uint256) {
        return csvFactory.avgPriceFactor();
    }
}
