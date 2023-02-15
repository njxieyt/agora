// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ILogisticsLookup {
    /**
        @return 1:Shipped 2:Delivered
     */
    function getLogisticsState(string calldata rawLogisticsNo)
        external
        view
        returns (uint8);

    function setLogisticsState(bytes32 logisticsNo, uint8 state) external;
}
