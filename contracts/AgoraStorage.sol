// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;
import {Merchandise} from "./Merchandise.sol";
import {ILogisticsLookup} from "./interfaces/ILogisticsLookup.sol";
import {DataTypes} from "./libraries/types/DataTypes.sol";

abstract contract AgoraStorage {
    Merchandise public mToken;
    uint16 public marginRate;
    uint16 public feeRate;
    ILogisticsLookup public logisticsLookup;
    // Auto increase token id;
    uint256 public currentTokenId;
    uint256 public returnPeriod;

    /**
     * @notice Record the fees' and claims total
     */
    DataTypes.FeeInfo public feeInfo;

    /**
     * @notice Map of the user's info
     */
    mapping(address => DataTypes.UserInfo) public users;

    /**
     * @notice Map of the good's info
     */
    mapping(uint256 => DataTypes.MerchandiseInfo) public merchandiseInfo;

    /**
     * @notice Map of token ID of buyer and their logisticsInfo
     * @dev Multiple buyers can own the same token ID
     */
    mapping(uint256 => mapping(address => DataTypes.Logistics))
        public logisticsInfo;
}
