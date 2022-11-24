// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.9;

interface IPrimaryMarket {
    function issue(
        uint256 id,
        uint256 value,
        uint256 maxYield
    ) external returns (bool success);

    function repay(uint256 id, uint256 value) external returns (bool success);

    function claim(uint256 id, uint256 value) external returns (bool success);

    function redeem(uint256 id, uint256 value) external returns (bool success);

    function liquidate(uint256 id, uint256 value) external returns (bool success);

    function tokenId(uint256 maturity, address issuer) external pure returns (uint256 id);

    function tokenData(uint256 id) external pure returns (uint256 maturity, address issuer);

    function riskFreeYield() external pure returns (uint256 yield);
}
