// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library Calculate {
    using SafeMath for uint256;
    uint16 public constant PRECISION = 10**2;

    function marginPrice(
        uint256 price,
        uint16 marginRate,
        uint16 feeRate
    ) external pure returns (uint256, uint256) {
        return (
            price.mul(marginRate).div(PRECISION).div(100),
            price.mul(feeRate).div(PRECISION).div(100)
        );
    }
}
