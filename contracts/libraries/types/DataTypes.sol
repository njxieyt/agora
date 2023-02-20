// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

library DataTypes {
    struct SellParams {
        // The identifier of a merchandise
        uint256 tokenId;
        // The cost of a merchandise
        uint256 price;
        // The sales amount
        uint16 amount;
        // The margin ratio that the seller needs to pay
        uint16 marginRate;
        // The fee ratio that the seller needs to pay
        uint16 feeRate;
        // The URL of the merchandise's information
        string newUri;
    }
}
