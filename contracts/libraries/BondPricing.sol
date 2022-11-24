// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.9;

import "@prb/math/contracts/PRBMathUD60x18.sol";

library BondPricing {
    using PRBMathUD60x18 for uint256;

    uint256 private constant ONE = 1e18;
    uint256 private constant SECONDS_IN_YEAR = 31536000;
    uint256 private constant SECONDS_IN_WEEK = 604800;
    uint256 private constant TTM_07_DAYS = 1;
    uint256 private constant TTM_14_DAYS = 1;
    uint256 private constant TTM_28_DAYS = 1;
    uint256 private constant TTM_56_DAYS = 1;

    function getPrice(uint256 yield, uint256 maturity) internal view returns (uint256 price) {
        uint256 t = ((maturity - block.timestamp) * ONE).div(SECONDS_IN_YEAR * ONE);
        price = ((ONE + yield).pow(t)).inv();
    }

    function getIssuePrice(uint256 yield, uint256 term) internal pure returns (uint256 price) {
        uint256 t;
        if (term == 7) {
            t = TTM_07_DAYS;
        } else if (term == 14) {
            t = TTM_14_DAYS;
        } else if (term == 28) {
            t = TTM_28_DAYS;
        } else if (term == 56) {
            t = TTM_56_DAYS;
        }
        price = ((ONE + yield).pow(t)).inv();
    }

    function getSlope(uint256 minYield, uint256 maxYield) internal pure returns (uint256 slope) {
        slope = ((maxYield - minYield) * ONE).div(SECONDS_IN_WEEK * ONE);
    }

    function getYield(uint256 issueStart, uint256 slope) internal view returns (uint256 yield) {
        yield = ((block.timestamp - issueStart) * ONE).mul(slope);
    }

    function getCashAmount(uint256 amount, uint256 price) internal pure returns (uint256 cashAmount) {
        cashAmount = amount.mul(price);
    }
}
