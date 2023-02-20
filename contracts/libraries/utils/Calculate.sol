// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

library Calculate {
    uint16 public constant PRECISION = 10 ** 2;

    function marginPrice(
        uint256 price,
        uint16 marginRate,
        uint16 feeRate
    ) external pure returns (uint256, uint256) {
        return (
            (price * marginRate) / PRECISION / 100,
            (price * feeRate) / PRECISION / 100
        );
    }
}
