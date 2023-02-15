// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

library States {
    // Logistics state 1:Shipped 2:Delivered
    uint8 public constant LOGISTICS_SHIPPED = 1;
    uint8 public constant LOGISTICS_DELIVERED = 2;
    // 7 days
    uint256 public constant DAYS_7_BLOCK_NUMBER = 50400;
}