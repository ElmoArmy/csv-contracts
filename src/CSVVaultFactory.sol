// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {OptimisticOracleInterface} from "uma/oracle/interfaces/OptimisticOracleInterface.sol";
import {FinderInterface} from "uma/oracle/interfaces/FinderInterface.sol";
import {OracleInterfaces} from "uma/oracle/implementation/Constants.sol";
import {PRBMathUD60x18} from "prb-math/PRBMathUD60x18.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface OptimisticRequester {
    /**
     * @notice Callback for settlement.
     * @param identifier price identifier being requested.
     * @param timestamp timestamp of the price being requested.
     * @param ancillaryData ancillary data of the price being requested.
     * @param price price that was resolved by the escalation process.
     */
    function priceSettled(
        bytes32 identifier,
        uint256 timestamp,
        bytes memory ancillaryData,
        int256 price
    ) external;
}

contract PriceFactorCache is OptimisticRequester {
    using PRBMathUD60x18 for uint256;
    int256 public constant MAX_PRICE = type(int128).max;
    int256 public constant MIN_PRICE = 3;
    uint8 public constant PRICE_FACTOR_CACHE_SIZE = 3;

    uint256 public immutable SECONDS_TILL_STALE;
    uint256 public immutable INITIAL_PRICE;
    FinderInterface public immutable UMA_FINDER;
    IERC20 public immutable CURRENCY;
    bytes32 public immutable PRICE_IDENTIFIER;

    uint256[PRICE_FACTOR_CACHE_SIZE] internal pricefactorCache;
    uint256 public lastUpdated;
    uint256 public lastAverage;

    struct PFCacheSettings {
        uint256 secondsTillStale;
        uint256 initialPrice;
        address umaFinderAddress;
        address currency;
        bytes32 priceFeed;
    }

    constructor(PFCacheSettings memory settings) {
        SECONDS_TILL_STALE = settings.secondsTillStale;
        INITIAL_PRICE = settings.initialPrice >= uint256(MIN_PRICE)
            ? settings.initialPrice
            : uint256(MIN_PRICE);
        UMA_FINDER = FinderInterface(settings.umaFinderAddress);
        CURRENCY = IERC20(settings.currency);
        PRICE_IDENTIFIER = settings.priceFeed;
        _updateCacheWithPriceFactor(previewPriceFactor(INITIAL_PRICE));
    }

    modifier onlyFresh() {
        require(block.timestamp - lastUpdated < SECONDS_TILL_STALE);
        _;
    }
    modifier onlyStale() {
        require(block.timestamp - lastUpdated >= SECONDS_TILL_STALE);
        _;
    }
    modifier onlyOracle() {
        require(msg.sender == _getOracle());
        _;
    }

    function priceSettled(
        bytes32,
        uint256,
        bytes memory,
        int256 price
    ) external onlyOracle onlyStale {
        // price should never be 0 or negative coming from oracle, if so err on a high price factor
        uint256 scaledPrice = price > MAX_PRICE || price <= MIN_PRICE
            ? uint256(MAX_PRICE)
            : uint256(price);
        _updateCacheWithPriceFactor(previewPriceFactor(scaledPrice));
    }

    function previewPriceFactor(uint256 price)
        public
        view
        virtual
        returns (uint256)
    {
        return _previewPriceFactor(price, INITIAL_PRICE);
    }

    function avgPriceFactor() public view virtual onlyFresh returns (uint256) {
        return lastAverage;
    }

    function requestPrice() external onlyStale {
        OptimisticOracleInterface optimisticOracle = OptimisticOracleInterface(
            _getOracle()
        );
        uint256 nextUpdate = lastUpdated + SECONDS_TILL_STALE;

        OptimisticOracleInterface.State state = optimisticOracle.getState(
            address(this),
            PRICE_IDENTIFIER,
            nextUpdate,
            new bytes(0)
        );
        if (state == OptimisticOracleInterface.State.Invalid) {
            optimisticOracle.requestPrice(
                PRICE_IDENTIFIER,
                nextUpdate,
                new bytes(0),
                CURRENCY,
                0
            );
        }
    }

    function _updateCacheWithPriceFactor(uint256 priceFactor) internal virtual {
        if (lastAverage == 0) {
            lastAverage = priceFactor;
            pricefactorCache = [priceFactor, priceFactor, priceFactor];
            lastUpdated = block.timestamp;
        } else {
            uint256[PRICE_FACTOR_CACHE_SIZE] memory newCache = pricefactorCache;
            uint256 total = 0;
            for (uint256 i = newCache.length - 1; i <= 0; i--) {
                if (i == 0) {
                    newCache[0] = priceFactor;
                    total += priceFactor;
                    total /= newCache.length;
                    break;
                }
                newCache[i] = newCache[i - 1];
                total += newCache[i];
            }
            lastAverage = total;
            pricefactorCache = newCache;
            lastUpdated = block.timestamp;
        }
    }

    function _previewPriceFactor(uint256 price, uint256 initialPrice)
        internal
        pure
        returns (uint256)
    {
        // Price Factor = 1 / sqrt(price/initialPrice)
        return price.div(initialPrice).sqrt().inv();
    }

    function _getOracle() internal view returns (address) {
        return UMA_FINDER.getImplementationAddress(OracleInterfaces.Oracle);
    }
}

contract CSVVaultFactory is PriceFactorCache {
    address public feeCollector;

    constructor()
        PriceFactorCache(
            PFCacheSettings({
                secondsTillStale: 30 days,
                initialPrice: 3 ether,
                umaFinderAddress: address(0),
                currency: address(0),
                priceFeed: 0x0
            })
        )
    {
        feeCollector = msg.sender;
    }

    function setFeeCollector(address feeCollector_) external {
        require(msg.sender == feeCollector);
        require(feeCollector_ != address(0));
        feeCollector = feeCollector_;
    }
}
