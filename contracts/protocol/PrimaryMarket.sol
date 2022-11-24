// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import "../interfaces/IPrimaryMarket.sol";
import "../interfaces/IZerobondToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PrimaryMarket is IPrimaryMarket {
    struct Issuance {
        uint256 id;
        uint256 value;
        uint256 term;
        uint256 start;
        uint256 end;
        uint256 minYield;
        uint256 maxYield;
        uint256 slope;
    }

    struct Price {
        uint256 yield;
        uint256 price;
    }

    uint256 private constant RISKFREE_YIELD = 2 * 1e16;
    uint256 private constant EPOCH_TIME_INIT = 1667347199;
    uint256 private constant SECONDS_IN_WEEK = 604800;
    uint256 private constant SECONDS_IN_DAY = 86400;
    uint256 private constant MATURITY_BITSHIFT = 160;
    uint256 private constant MATURITY_BITMASK = 2**96 - 1;
    uint256 private constant ISSUER_BITMASK = 2**160 - 1;
    uint256 private constant YIELD_RANGE_MIN = 1e16;
    uint256 private constant YIELD_RANGE_MAX = 9999 * 1e14;

    IZerobondToken public immutable bondToken;
    IERC20 public immutable cashToken;

    constructor(address bondAddress, address cashAddress) {
        bondToken = IZerobondToken(bondAddress);
        cashToken = IERC20(cashAddress);
    }

    function _riskFreeYield() private pure returns (uint256 yield) {
        yield = RISKFREE_YIELD;
    }

    function riskFreeYield() external pure returns (uint256 yield) {
        yield = _riskFreeYield();
    }

    function tokenId(uint256 maturity, address issuer) external pure returns (uint256 id) {
        id = _tokenId(maturity, issuer);
    }

    function _tokenId(uint256 maturity, address issuer) private pure returns (uint256 id) {
        require((maturity - EPOCH_TIME_INIT) % SECONDS_IN_DAY == 0, "Invalid Maturity");
        require(issuer != address(0), "Zero Address");
        id = (maturity << MATURITY_BITSHIFT) | uint256(uint160(issuer));
    }

    function tokenData(uint256 id) external pure returns (uint256 maturity, address issuer) {}

    function _tokenData(uint256 id) private pure returns (uint256 maturity, address issuer) {
        maturity = (id & (MATURITY_BITMASK << MATURITY_BITSHIFT)) >> MATURITY_BITSHIFT;
        require((maturity - EPOCH_TIME_INIT) % SECONDS_IN_DAY == 0, "Invalid Maturity");
        issuer = address(uint160(id & ISSUER_BITMASK));
    }

    function issue(
        uint256 id,
        uint256 value,
        uint256 maxYield
    ) external returns (bool success) {}

    function _previewIssue(
        uint256 term,
        uint256 value,
        uint256 maxYield
    )
        private
        returns (
            uint256 id,
            uint256 start,
            uint256 end,
            Price maxPrice,
            Price minPrice
        )
    {
        require(value >= 1e18, "Zero Amount");
        require(term == 7 || term == 14 || term == 28 || term == 56, "Invalid Term");
        require(maxYield >= YIELD_RANGE_MIN && maxYield <= YIELD_RANGE_MAX, "Invalid MaxYield");
    }

    function repay(uint256 id, uint256 value) external returns (bool success) {}

    function claim(uint256 id, uint256 value) external returns (bool success) {}

    function redeem(uint256 id, uint256 value) external returns (bool success) {}

    function liquidate(uint256 id, uint256 value) external returns (bool success) {}
}
