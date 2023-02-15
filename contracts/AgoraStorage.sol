// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;
import "./Merchandise.sol";
import "./interfaces/ILogisticsLookup.sol";

abstract contract AgoraStorage {
    Merchandise public mToken;
    // Default margin percentage (Unit: percentage with 2 decimal)
    uint16 public marginRate;
    // Default seller's fee percentage (Unit: percentage with 2 decimal)
    uint16 public feeRate;
    //address logisticsLookupAddress;
    ILogisticsLookup logisticsLookup;
    // Auto increase token id;
    uint256 internal _currentTokenId;

    // Map of users address and their info
    mapping(address => UserInfo) public users;
    struct UserInfo {
        // Unit: percentage with 2 decimal
        uint16 marginRate;
        // Unit: percentage with 2 decimal
        uint16 feeRate;
        // user's rating value
        uint8 rating;
    }

    // Map of tokenId and their price
    mapping(uint256 => MerchandiseInfo) public merchandiseInfo;
    struct MerchandiseInfo {
        uint256 price;
        // who can modify price
        address seller;
        // margin of amount
        uint256 margin;
    }

    // Map of tokenId of buyer and their logisticsInfo
    // More than one tokenId can have multiple different buyers
    mapping(uint256 => mapping(address => Logistics)) public logisticsInfo;
    struct Logistics {
        uint16 amount;
        // at time price
        uint256 price;        
        string logisticsNo;
        // hash the delivery address by keccak256
        bytes32 deliveryAddress;
        // block number
        uint256 orderTime;
        // block number
        uint256 completeTime;
        // block number
        uint256 returnTime;
        
    }
}
