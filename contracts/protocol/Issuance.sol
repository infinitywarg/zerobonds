// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

import "../libraries/BondPricing.sol";
import "../interfaces/IZerobondToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Issuance {
    struct Auction {
        uint256 totalAmount;
        uint256 unsoldAmount;
        uint256 issueStart;
        uint256 issueEnd;
        uint256 minYield;
        uint256 maxYield;
        uint256 slope;
    }

    uint256 private constant SECONDS_IN_WEEK = 604800;
    uint256 private constant SECONDS_IN_DAY = 86400;
    uint256 private constant EPOCH_TIME_INIT = 1667347199;
    uint256 private constant MATURITY_BITSHIFT = 160;
    uint256 private constant MATURITY_BITMASK = 2**96 - 1;
    uint256 private constant ISSUER_BITMASK = 2**160 - 1;
    uint256 private constant YIELD_RANGE_MIN = 1e16;
    uint256 private constant YIELD_RANGE_MAX = 9999 * 1e14;

    IZerobondToken private immutable zerobond;
    IERC20 private immutable cash;

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => uint256) public claimedAmount;
    mapping(uint256 => uint256) public repaidAmount;

    constructor(address zerobondToken, address cashToken) {
        zerobond = IZerobondToken(zerobondToken);
        cash = IERC20(cashToken);
    }

    function getRiskFreeYield() public pure returns (uint256 yield) {
        return 200;
    }

    function getTokenId(uint256 maturity, address issuer) public pure returns (uint256) {
        require((maturity - EPOCH_TIME_INIT) % SECONDS_IN_DAY == 0, "Invalid Maturity");
        require(issuer != address(0), "Zero Address");
        uint256 id = (maturity << MATURITY_BITSHIFT) | uint256(uint160(issuer));
        return id;
    }

    function getTokenData(uint256 id) public pure returns (uint256, address) {
        uint256 maturity = (id & (MATURITY_BITMASK << MATURITY_BITSHIFT)) >> MATURITY_BITSHIFT;
        require((maturity - EPOCH_TIME_INIT) % SECONDS_IN_DAY == 0, "Invalid Maturity");
        address issuer = address(uint160(id & ISSUER_BITMASK));
        return (maturity, issuer);
    }

    function previewIssue(
        uint256 amount,
        uint256 term,
        uint256 maxYield
    )
        public
        view
        returns (
            uint256 issueStart,
            uint256 issueEnd,
            uint256 maturity,
            uint256 minYield,
            uint256 slope,
            uint256 tokenId,
            uint256 minPrice,
            uint256 maxPrice
        )
    {
        require(amount >= 1e18, "Zero Amount");
        require(term == 7 || term == 14 || term == 28 || term == 56, "Invalid Term");
        require(maxYield >= YIELD_RANGE_MIN && maxYield <= YIELD_RANGE_MAX, "Yield out of Range");

        issueStart = block.timestamp;
        issueEnd =
            issueStart +
            SECONDS_IN_WEEK +
            SECONDS_IN_DAY -
            ((issueStart + SECONDS_IN_WEEK) % SECONDS_IN_DAY) -
            1;
        maturity = issueEnd + (term * SECONDS_IN_DAY);
        minYield = getRiskFreeYield();
        slope = BondPricing.getSlope(minYield, maxYield);
        tokenId = getTokenId(maturity, msg.sender);
        minPrice = BondPricing.getIssuePrice(minYield, term);
        maxPrice = BondPricing.getIssuePrice(maxYield, term);
    }

    function issue(
        uint256 amount,
        uint256 term,
        uint256 maxYield
    ) external {
        (uint256 issueStart, uint256 issueEnd, , uint256 minYield, uint256 slope, uint256 tokenId, , ) = previewIssue(
            amount,
            term,
            maxYield
        );

        Auction memory auction = Auction(amount, amount, issueStart, issueEnd, minYield, maxYield, slope);
        auctions[tokenId] = auction;
        zerobond.mint(address(this), tokenId, amount, "");
    }

    function repay(uint256 tokenId, uint256 amount) external {
        (uint256 maturity, address issuer) = getTokenData(tokenId);
        require(msg.sender == issuer, "not issuer");
        require(
            (maturity > block.timestamp && maturity - block.timestamp <= (SECONDS_IN_WEEK / 2)) ||
                (maturity <= block.timestamp && block.timestamp - maturity <= (SECONDS_IN_WEEK / 2)),
            "repay too early/late"
        );

        repaidAmount[tokenId] += amount;
        cash.transferFrom(msg.sender, address(this), amount);
    }

    function previewClaim(uint256 tokenId, uint256 amount)
        public
        view
        returns (
            uint256 yield,
            uint256 price,
            uint256 cashAmount
        )
    {
        require(auctions[tokenId].unsoldAmount >= amount, "Amount not available");
        require(auctions[tokenId].issueEnd >= block.timestamp, "Auction Finished");
        require(auctions[tokenId].issueStart <= block.timestamp, "Auction not Started");
        yield = BondPricing.getYield(auctions[tokenId].issueStart, auctions[tokenId].slope);
        (uint256 maturity, ) = getTokenData(tokenId);
        price = BondPricing.getPrice(yield, maturity);
        cashAmount = BondPricing.getCashAmount(amount, price);
    }

    function claim(uint256 tokenId, uint256 amount) external {
        (, , uint256 cashAmount) = previewClaim(tokenId, amount);
        (, address issuer) = getTokenData(tokenId);
        auctions[tokenId].unsoldAmount -= amount;
        claimedAmount[tokenId] += amount;
        zerobond.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");
        cash.transferFrom(msg.sender, issuer, cashAmount);
    }

    function redeem(uint256 tokenId, uint256 amount) external {
        (uint256 maturity, address issuer) = getTokenData(tokenId);
        zerobond.burn(msg.sender, tokenId, amount);
    }
}
