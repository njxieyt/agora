// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library Calculate {
    using SafeMath for uint256;

    function marginPrice(
        uint256 price,
        uint16 marginRate,
        uint16 feeRate
    ) external pure returns (uint256, uint256) {
        uint256 marginRaw = price.mul(marginRate);
        return (marginRaw.div(10000), marginRaw.mul(feeRate).div(10000));
    }
}
