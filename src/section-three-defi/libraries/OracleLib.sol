// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/local/src/data-feeds/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Carlos Zambrano - thecil
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, the function will revert, and render the DSCEngine unusable.
 * We want the DSCEngine to freeze if prices become stale.
 *
 * So if Chainlink network explodes and you have a lot of money locked in the protocol... to bad.
 */
library OracleLib {
    error OracleLib__StalePriceError(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    uint256 public constant STALE_PRICE_DURATION = 3 hours;

    function staleCheckLatestRoundData(
        AggregatorV3Interface _priceFeed
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = _priceFeed.latestRoundData();

        uint256 secondsSinceLastUpdate = block.timestamp - updatedAt;
        if (secondsSinceLastUpdate > STALE_PRICE_DURATION) {
            revert OracleLib__StalePriceError(
                roundId,
                answer,
                startedAt,
                updatedAt,
                answeredInRound
            );
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
