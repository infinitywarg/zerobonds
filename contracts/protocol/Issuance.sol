// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.9;

contract Issuance {
    struct Auction {
        uint256 amount;
        uint96 issueStart;
        uint96 issueEnd;
        uint32 minYield;
        uint32 maxYield;
        uint256 slope;
    }

    uint96 private constant AUCTION_DURATION = 604800;
    uint96 private constant SECONDS_IN_DAY = 86400;
    uint96 private constant SECONDS_IN_YEAR = 31536000;
    uint96 private constant EPOCH_TIME_INIT = 1667347199;
    uint256 private constant MATURITY_BITSHIFT = 160;
    uint256 private constant MATURITY_BITMASK = 2**96 - 1;
    uint256 private constant ISSUER_BITMASK = 2**160 - 1;
    uint32 private constant YIELD_RANGE_MIN = 1;
    uint32 private constant YIELD_RANGE_MAX = 9999;

    mapping(uint256 => Auction) public auctions;

    function getBondPrice(uint96 maturity, uint32 yield) public view returns (uint256 price) {
        uint256 ytm = ((maturity - block.timestamp) * 1e18) / 31536000;
    }

    function getRiskFreeYield() public pure returns (uint32 yield) {
        return 200;
    }

    function getAuctionData(uint256 tokenId) public view returns (uint32 yield, uint256 price) {
        require(auctions[tokenId].issueEnd >= block.timestamp, "Auction Finished");
    }

    function getTokenId(uint96 maturity, address issuer) public pure returns (uint256) {
        require((maturity - EPOCH_TIME_INIT) % SECONDS_IN_DAY == 0, "Invalid Maturity");
        require(issuer != address(0), "Zero Address");
        uint256 id = (uint256(maturity) << MATURITY_BITSHIFT) | uint256(uint160(issuer));
        return id;
    }

    function getTokenData(uint256 id) public pure returns (uint96, address) {
        uint96 maturity = uint96((id & (MATURITY_BITMASK << MATURITY_BITSHIFT)) >> MATURITY_BITSHIFT);
        require((maturity - EPOCH_TIME_INIT) % SECONDS_IN_DAY == 0, "Invalid Maturity");
        address issuer = address(uint160(id & ISSUER_BITMASK));
        return (maturity, issuer);
    }

    function previewIssue(
        uint256 amount,
        uint8 term,
        uint32 maxYield
    )
        public
        view
        returns (
            uint96 issueStart,
            uint96 issueEnd,
            uint96 maturity,
            uint32 minYield,
            uint256 slope,
            uint256 tokenId
        )
    {
        require(amount >= 1e6, "Zero Amount");
        require(term == 14 || term == 28 || term == 56 || term == 91, "Invalid Term");
        require(maxYield >= YIELD_RANGE_MIN && maxYield <= YIELD_RANGE_MAX, "Yield out of Range");

        issueStart = uint96(block.timestamp);
        issueEnd =
            issueStart +
            AUCTION_DURATION +
            SECONDS_IN_DAY -
            ((issueStart + AUCTION_DURATION) % SECONDS_IN_DAY) -
            1;
        maturity = issueEnd + (term * SECONDS_IN_DAY);
        minYield = getRiskFreeYield();
        slope = ((maxYield - minYield) * 1e6) / AUCTION_DURATION;
        tokenId = getTokenId(maturity, msg.sender);
    }

    function issue(
        uint256 amount,
        uint8 term,
        uint32 maxYield
    ) external {
        (uint96 issueStart, uint96 issueEnd, , uint32 minYield, uint256 slope, uint256 tokenId) = previewIssue(
            amount,
            term,
            maxYield
        );

        Auction memory auction = Auction(amount, issueStart, issueEnd, minYield, maxYield, slope);
        auctions[tokenId] = auction;
    }

    function claim() external {}
}
