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

    /**
     *
     * @param tokenId The identifier of a merchandise
     * @param seller The vendor of goods
     * @param fee The cost of selling fees
     */
    event Sell(uint256 indexed tokenId, address indexed seller, uint256 fee);

    /**
     * @notice Let the seller know that you have a new order
     * @param tokenId The identifier of a merchandise
     * @param buyer The purchaser of goods
     */
    event Buy(uint256 indexed tokenId, address indexed buyer);

    /**
     * @notice Notify the buyer that the seller has shipped
     * @param tokenId The identifier of a merchandise
     * @param seller The vendor of goods
     * @param buyer The purchaser of goods
     */
    event Ship(uint256 indexed tokenId, address indexed seller, address buyer);

    /**
     * @notice Let the buyer know that the goods have been signed for
     * @param tokenId The identifier of a merchandise
     * @param buyer The purchaser of goods
     */
    event deliver(uint256 indexed tokenId, address indexed buyer);

    /**
     * @notice Let the recipient know that the order is done
     * @param tokenId The identifier of a merchandise
     * @param shipper The owner of the goods, can be either the seller when selling or the buyer when returning
     * @param recipient The recipient of goods
     */
    event settle(
        uint256 indexed tokenId,
        address indexed shipper,
        address recipient
    );

    /**
     * @notice Record the margin was released
     * @param tokenId The identifier of a merchandise
     * @param seller The owner of the margin
     */
    event releaseMargin(uint256 indexed tokenId, address seller);

    /**
     * @notice Notify the seller that the buyer has a refund
     * @param tokenId The identifier of a merchandise
     * @param buyer The purchaser of goods
     */
    event refund(uint256 indexed tokenId, address buyer);

    /**
     * @notice Inform the seller that the buyer returned the goods
     * @param tokenId The identifier of a merchandise
     * @param buyer The purchaser of goods
     */
    event returning(uint256 indexed tokenId, address buyer);

    /**
     * @notice Seller sells the goods
     * @param tokenId The identifier of a merchandise
     * @param price The cost of a merchandise
     * @param amount The sales amount
     * @param marginRate The margin ratio that the seller needs to pay
     * @param feeRate The fee ratio that the seller needs to pay
     * @param newUri The URL of the merchandise's information
     * @param mToken Token of merchandise
     * @param merchandiseInfo Basic merchandise information
     * @param users Basic users information
     */
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
        require(price > 0, Errors.INVALID_PRICE);
        // Get the caller's margin and fees
        AgoraStorage.UserInfo storage userInfo = users[msg.sender];
        (uint256 margin, uint256 fee) = Calculate.marginPrice(
            price.mul(amount),
            userInfo.marginRate == 0 ? marginRate : userInfo.marginRate,
            userInfo.feeRate == 0 ? feeRate : userInfo.feeRate
        );
        require(msg.value >= margin + fee, Errors.INSUFFICIENT_MARGIN);

        // Margin of the merchandise
        merchandiseInfo[tokenId].margin += margin;
        // Price of the merchandise
        merchandiseInfo[tokenId].price = price;
        // The seller of the merchandise
        merchandiseInfo[tokenId].seller = msg.sender;

        // Mint the merchandise's token
        mToken.mint(msg.sender, tokenId, amount, newUri);

        emit Sell(tokenId, msg.sender, fee);
    }

    /**
     *
     * @param tokenId The identifier of a merchandise
     * @param amount The purchase amount
     * @param deliveryAddress Shipping address
     * @param merchandiseInfo Basic merchandise information
     * @param logisticsInfo Transaction logistics information
     */
    function buyProcess(
        uint256 tokenId,
        uint16 amount,
        bytes32 deliveryAddress,
        mapping(uint256 => AgoraStorage.MerchandiseInfo)
            storage merchandiseInfo,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo
    ) external {
        require(amount > 0, Errors.INVALID_AMOUNT);
        uint256 price = merchandiseInfo[tokenId].price;
        require(msg.value >= price * amount, Errors.NOT_ENOUGH_ETH);

        // Add new logistics info
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
     * @notice The seller confirmed goods to be shipped
     * @param tokenId The identifier of a merchandise
     * @param to The buyer
     * @param logisticsNo Shipping number
     * @param mToken Token of merchandise
     * @param logisticsInfo Transaction logistics information
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
        // There is an order
        require(logistics.orderTime > 0, Errors.NO_ORDER);
        // Buyer has not requested a refund or returned the goods
        require(logistics.returnTime == 0, Errors.ORDER_CANCELED);
        // The caller owns the goods
        address seller = msg.sender;
        require(logistics.seller == seller, Errors.CALLER_NOT_THE_OWNER);
        // The seller has enough stock
        uint256 amount = mToken.balanceOf(seller, tokenId);
        require(amount >= logistics.amount, Errors.INSUFFICIENT_AMOUNT);

        // Update logistics info
        logistics.logisticsNo = logisticsNo;

        emit Ship(tokenId, seller, to);
    }

    /**
     * @notice The goods has been delivered to the buyer
     * @param tokenId The identifier of a merchandise
     * @param to buyer
     * @param mToken Token of merchandise
     * @param logisticsLookup Logistics Oracle
     * @param logisticsInfo Transaction logistics information
     */
    function deliverProcess(
        uint256 tokenId,
        address to,
        Merchandise mToken,
        ILogisticsLookup logisticsLookup,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo
    ) external {
        AgoraStorage.Logistics storage logistics = logisticsInfo[tokenId][to];
        uint16 amount = logistics.amount;
        // Check order amount
        require(amount > 0, Errors.NO_ORDER);
        // The order has been delivered
        string memory logisticsNo = logistics.logisticsNo;
        require(
            bytes(logisticsNo).length > 0 &&
                logisticsLookup.getLogisticsState(logisticsNo) ==
                States.LOGISTICS_DELIVERED,
            Errors.ORDER_UNCOMPLETED
        );
        // The seller has enough stock
        uint256 amountOfToken = mToken.balanceOf(logistics.seller, tokenId);
        require(amountOfToken >= amount, Errors.INSUFFICIENT_AMOUNT);

        // Transfer mToken to buyer
        mToken.safeTransferFrom(logistics.seller, to, tokenId, amount, "");

        // Update logistics info
        logistics.completeTime = block.number;

        emit deliver(tokenId, to);
    }

    /**
     * @notice The owner of goods wants to settle
     * @param tokenId The identifier of a merchandise
     * @param to The recipient of goods
     * @param logisticsInfo Transaction logistics information
     * @param returnPeriod The recipient's return period
     */
    function settleProcess(
        uint256 tokenId,
        address to,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo,
        uint256 returnPeriod
    ) external {
        AgoraStorage.Logistics storage logistics = logisticsInfo[tokenId][to];
        uint16 amount = logistics.amount;
        // Check order amount
        require(amount > 0, Errors.NO_ORDER);
        // The recipient hasn't returned the goods yet
        require(logistics.returnTime == 0, Errors.MERCHANDISE_RETURNED);
        // The return window has been closed
        require(
            logistics.completeTime > 0 &&
                (block.number > logistics.completeTime + returnPeriod),
            Errors.NOT_ENOUGH_TIME
        );
        address payable shipper = payable(msg.sender);
        // Settlement partner cannot be oneself
        require(shipper != to, Errors.SETTLEMENT_PARTNER_IS_ONESELF);
        // The caller owns the goods
        require(logistics.seller == shipper, Errors.CALLER_NOT_THE_OWNER);

        // Transfer ETH to caller
        shipper.transfer(logistics.price * amount);

        emit settle(tokenId, shipper, to);
    }

    /**
     * @notice The seller wants to release the excess margin
     * @param tokenId The identifier of a merchandise
     * @param marginRate The margin ratio that the seller needs to pay
     * @param feeRate The fee ratio that the seller needs to pay
     * @param mToken Token of merchandise
     * @param merchandiseInfo Basic merchandise information
     * @param users Basic users information
     */
    function releaseMarginProcess(
        uint256 tokenId,
        uint16 marginRate,
        uint16 feeRate,
        Merchandise mToken,
        mapping(uint256 => AgoraStorage.MerchandiseInfo)
            storage merchandiseInfo,
        mapping(address => AgoraStorage.UserInfo) storage users
    ) external {
        AgoraStorage.MerchandiseInfo
            storage tokenOfMerchandise = merchandiseInfo[tokenId];
        address seller = tokenOfMerchandise.seller;
        // The caller owns the goods
        require(msg.sender == seller, Errors.CALLER_NOT_THE_OWNER);
        AgoraStorage.UserInfo storage userInfo = users[seller];
        (uint256 realTimeMargin, ) = Calculate.marginPrice(
            tokenOfMerchandise.price.mul(mToken.balanceOf(seller, tokenId)),
            userInfo.marginRate == 0 ? marginRate : userInfo.marginRate,
            userInfo.feeRate == 0 ? feeRate : userInfo.feeRate
        );
        // The caller has more excess margin
        require(
            tokenOfMerchandise.margin > realTimeMargin,
            Errors.MARGIN_BELOW_THRESHOLD
        );

        // Transfer excess margin
        payable(seller).transfer(tokenOfMerchandise.margin - realTimeMargin);

        emit releaseMargin(tokenId, seller);
    }

    /**
     * @notice Allow the buyer to request refund if goods have not yet been shipped
     * @param tokenId The identifier of a merchandise
     * @param logisticsInfo Transaction logistics information
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
        // There is an order
        require(logistics.amount > 0, Errors.NO_ORDER);
        // the seller has not shipped the goods
        require(
            bytes(logistics.logisticsNo).length < 1,
            Errors.LOGISTICS_PROCESSED
        );

        // Update logistics info
        logistics.returnTime = block.number;

        // Transfer ETH to caller
        payable(msg.sender).transfer(logistics.price * logistics.amount);

        emit refund(tokenId, buyer);
    }

    /**
     * @notice Allow the buyer to request returns within the return period
     * @param tokenId The identifier of a merchandise
     * @param amount The returned amount
     * @param logisticsNo Shipping number
     * @param deliveryAddress Shipping address
     * @param logisticsInfo Transaction logistics information
     * @param returnPeriod The recipient's return period
     */
    function returningProcess(
        uint256 tokenId,
        uint16 amount,
        string calldata logisticsNo,
        bytes32 deliveryAddress,
        mapping(uint256 => mapping(address => AgoraStorage.Logistics))
            storage logisticsInfo,
        uint256 returnPeriod
    ) external {
        address buyer = msg.sender;
        AgoraStorage.Logistics storage buyerLogistics = logisticsInfo[tokenId][
            buyer
        ];
        // The order has been completed
        require(buyerLogistics.completeTime > 0, Errors.ORDER_UNCOMPLETED);
        // The return window has not been closed yet
        require(
            block.number <= buyerLogistics.completeTime + returnPeriod,
            Errors.RETURN_TIME_EXPIRED
        );
        // The returning amount is valid
        require(
            amount > 0 && amount <= buyerLogistics.amount,
            Errors.AMOUNT_EXCEEDED
        );

        // Update logistics info
        buyerLogistics.returnTime = block.number;

        // Add new logistics info(buyer->seller)
        AgoraStorage.Logistics memory logistics;
        logistics.seller = buyer;
        logistics.amount = amount;
        logistics.logisticsNo = logisticsNo;
        logistics.deliveryAddress = deliveryAddress;
        logistics.orderTime = block.number;
        logistics.price = buyerLogistics.price;
        logisticsInfo[tokenId][buyerLogistics.seller] = logistics;

        emit returning(tokenId, buyer);
    }
}
