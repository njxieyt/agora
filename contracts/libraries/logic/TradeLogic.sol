// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../Merchandise.sol";
import "../constant/Errors.sol";
import "../constant/States.sol";
import {Calculate} from "../utils/Calculate.sol";
import {AgoraStorage} from "../../AgoraStorage.sol";
import {ILogisticsLookup} from "../../interfaces/ILogisticsLookup.sol";

library TradeLogic {
    using SafeMath for uint256;

    event Sell(uint256 indexed tokenId, address indexed seller, uint256 fee);
    event Buy(uint256 indexed tokenId, address indexed buyer);
    event Shipped(
        uint256 indexed tokenId,
        address indexed seller,
        address buyer
    );

    function sellProcess(
        uint256 tokenId,
        uint256 price,
        uint16 amount,
        uint16 marginRate,
        uint16 feeRate,
        string calldata newUri,
        Merchandise mToken,
        mapping(uint256 => AgoraStorage.MerchandiseInfo)
            storage merchandiseInfo,
        mapping(address => AgoraStorage.UserInfo) storage users
    ) external {
        require(bytes(newUri).length > 0, Errors.URI_NOT_DEFINED);

        // Get margin amount & fee
        AgoraStorage.UserInfo storage userInfo = users[msg.sender];
        (uint256 margin, uint256 fee) = Calculate.marginPrice(
            price.mul(amount),
            userInfo.marginRate == 0 ? marginRate : userInfo.marginRate,
            userInfo.feeRate == 0 ? feeRate : userInfo.feeRate
        );
        require(msg.value >= margin + fee, Errors.INSUFFICIENT_MARGIN);

        // Record margin of this merchandise amount
        merchandiseInfo[tokenId].margin += margin;
        // Record price of this merchandise
        merchandiseInfo[tokenId].price = price;
        // Record owner of this merchandise
        merchandiseInfo[tokenId].seller = msg.sender;
        // mint
        mToken.mint(msg.sender, tokenId, amount, newUri);

        emit Sell(tokenId, msg.sender, fee);
    }

    function buyProcess(
        uint256 tokenId,
        uint16 amount,
        bytes32 deliveryAddress,
        mapping(uint256 => AgoraStorage.MerchandiseInfo)
            storage merchandiseInfo,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo
    ) external {
        // Amount must be greater than 0'
        require(amount != 0, Errors.INVALID_AMOUNT);
        // Is enough price
        uint256 price = merchandiseInfo[tokenId].price;
        require(msg.value >= price * amount, Errors.NOT_ENOUGH_ETH);

        // Add new logisticsInfo
        AgoraStorage.Logistics memory logistics;
        logistics.seller = merchandiseInfo[tokenId].seller;
        logistics.amount = amount;
        logistics.deliveryAddress = deliveryAddress;
        logistics.orderTime = block.number;
        logistics.price = price;
        logisticsInfo[tokenId][msg.sender] = logistics;

        emit Buy(tokenId, msg.sender);
    }

    /**
        Seller shipped
     */
    function shipProcess(
        uint256 tokenId,
        address to,
        string calldata logisticsNo,
        Merchandise mToken,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo
    ) external {
        AgoraStorage.Logistics storage logistics = logisticsInfo[tokenId][to];
        // Valid order
        require(logistics.orderTime > 0, Errors.NO_ORDER);

        // Buyer has not requested a refund or returned the item
        require(logistics.returnTime == 0, Errors.ORDER_CANCELED);

        // Is owner of tokenId
        uint256 amount = mToken.balanceOf(msg.sender, tokenId);
        require(amount >= logistics.amount, Errors.INSUFFICIENT_AMOUNT);

        // Update logistics info
        logistics.logisticsNo = logisticsNo;

        emit Shipped(tokenId, msg.sender, to);
    }

    /**
        When logistics delivered update complete time
     */
    function deliverProcess(
        uint256 tokenId,
        address to,
        ILogisticsLookup logisticsLookup,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo
    ) external {
        mapping(address => AgoraStorage.Logistics)
            storage logisticsOfToken = logisticsInfo[tokenId];
        uint16 amount = logisticsOfToken[to].amount;
        require(amount > 0, Errors.NO_ORDER);

        // Lookup logistics state
        string memory logisticsNo = logisticsOfToken[to].logisticsNo;
        require(
            bytes(logisticsNo).length > 0 &&
                logisticsLookup.getLogisticsState(logisticsNo) ==
                States.LOGISTICS_DELIVERED,
            Errors.ORDER_UNCOMPLETED
        );

        // Update logistics info
        logisticsOfToken[to].completeTime = block.number;
    }

    /**
    Condition:1.delivered 2.complete time more than 7 days 3.no returned
     */
    function settleProcess(
        uint256 tokenId,
        address to,
        Merchandise mToken,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo,
        uint256 returnPeriod
    ) external {
        AgoraStorage.Logistics storage logistics = logisticsInfo[tokenId][to];
        uint16 amount = logistics.amount;
        require(amount > 0, Errors.NO_ORDER);

        // Is returned
        require(logistics.returnTime == 0, Errors.MERCHANDISE_RETURNED);

        // Is complete time more then 7 days
        require(
            logistics.completeTime > 0 &&
                (block.number > logistics.completeTime + returnPeriod),
            Errors.NOT_ENOUGH_TIME
        );

        address payable seller = payable(msg.sender);
        // Settlement partner cannot be oneself
        require(seller != to, Errors.SETTLEMENT_PARTNER_IS_ONESELF);

        // Check if the caller owns the item
        require(
            logistics.seller == seller,
            Errors.CALLER_NOT_THE_OWNER_OF_THE_ITEM
        );

        // Check item amount
        uint256 amountOfToken = mToken.balanceOf(seller, tokenId);
        require(amountOfToken >= amount, Errors.INSUFFICIENT_AMOUNT);

        // Transfer mToken to buyer
        mToken.safeTransferFrom(seller, to, tokenId, amount, "");

        // Send ETH to seller
        seller.transfer(logistics.price * amount);
    }

    function releaseMarginProcess(
        uint256 tokenId,
        uint16 marginRate,
        uint16 feeRate,
        Merchandise mToken,
        mapping(uint256 => AgoraStorage.MerchandiseInfo)
            storage merchandiseInfo,
        mapping(address => AgoraStorage.UserInfo) storage users
    ) external {
        // user deposit margin
        AgoraStorage.MerchandiseInfo
            storage tokenOfMerchandise = merchandiseInfo[tokenId];
        address seller = tokenOfMerchandise.seller;
        require(msg.sender == seller, Errors.INVALID_MARGIN_USER);

        // real margin
        AgoraStorage.UserInfo storage userInfo = users[seller];
        (uint256 realTimeMargin, ) = Calculate.marginPrice(
            tokenOfMerchandise.price.mul(mToken.balanceOf(seller, tokenId)),
            userInfo.marginRate == 0 ? marginRate : userInfo.marginRate,
            userInfo.feeRate == 0 ? feeRate : userInfo.feeRate
        );
        require(
            tokenOfMerchandise.margin > realTimeMargin,
            Errors.MARGIN_BELOW_THRESHOLD
        );

        // transfer excess margin
        payable(seller).transfer(tokenOfMerchandise.margin - realTimeMargin);
    }

    /**
        Allow user to request refund if goods have not yet been shipped
     */
    function refundProcess(
        uint256 tokenId,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo
    ) external {
        address buyer = msg.sender;
        AgoraStorage.Logistics storage logistics = logisticsInfo[tokenId][
            buyer
        ];

        // Valid order
        require(logistics.amount > 0, Errors.NO_ORDER);

        // Seller has not shipped the item
        require(
            bytes(logistics.logisticsNo).length < 1,
            Errors.LOGISTICS_PROCESSED
        );

        // Update logisticsInfo
        logistics.returnTime = block.number;

        // Transfer
        payable(msg.sender).transfer(logistics.price * logistics.amount);
    }

    function returningProcess(
        uint256 tokenId,
        uint16 amount,
        string calldata logisticsNo,
        bytes32 deliveryAddress,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo,
        uint256 returnPeriod
    ) external {
        AgoraStorage.Logistics storage buyerLogistics = logisticsInfo[tokenId][
            msg.sender
        ];
        // Check if order completed
        require(buyerLogistics.completeTime > 0, Errors.ORDER_UNCOMPLETED);

        // Check if expired, complete time less than 7 days
        require(
            block.number <= buyerLogistics.completeTime + returnPeriod,
            Errors.RETURN_TIME_EXPIRED
        );

        // Check return amount
        require(buyerLogistics.amount >= amount, Errors.AMOUNT_EXCEEDED);

        // Update logisticsInfo
        buyerLogistics.returnTime = block.number;
        // Add new logisticsInfo,buyer->seller
        AgoraStorage.Logistics memory logistics;
        logistics.seller = msg.sender;
        logistics.amount = amount;
        logistics.logisticsNo = logisticsNo;
        logistics.deliveryAddress = deliveryAddress;
        logistics.orderTime = block.number;
        logistics.price = buyerLogistics.price;
        logisticsInfo[tokenId][buyerLogistics.seller] = logistics;
    }
}
