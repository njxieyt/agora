// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./AgoraStorage.sol";
import {TradeLogic} from "./libraries/logic/TradeLogic.sol";
import {Errors} from "./libraries/constant/Errors.sol";

contract Agora is AgoraStorage, Initializable, Ownable {
    using SafeMath for uint256;

    function initialize(Merchandise merchandise, ILogisticsLookup lookup)
        public
        initializer
    {
        mToken = merchandise;
        logisticsLookup = lookup;
        // Unit: % with two decimal places(default 10%)
        marginRate = 1000;
        // Unit: % with two decimal places(default 0.1%)
        feeRate = 10;
    }

    function sell(
        uint16 amount,
        uint256 uintPrice,
        string calldata newUri
    ) external payable {
        TradeLogic.sellProcess(
            ++currentTokenId,
            uintPrice,
            amount,
            marginRate,
            feeRate,
            newUri,
            mToken,
            merchandiseInfo,
            users
        );
    }

    function buy(
        uint256 tokenId,
        uint16 amount,
        bytes32 deliveryAddress
    ) external payable {
        TradeLogic.buyProcess(
            tokenId,
            amount,
            deliveryAddress,
            merchandiseInfo,
            logisticsInfo
        );
    }

    function ship(
        uint256 tokenId,
        address to,
        string calldata logisticsNo
    ) external {
        TradeLogic.shipProcess(
            tokenId,
            to,
            logisticsNo,
            mToken,
            logisticsInfo
        );
    }

    function deliver(uint256 tokenId, address to) external {
        TradeLogic.deliverProcess(
            tokenId,
            to,
            logisticsLookup,
            logisticsInfo
        );
    }

    function settle(uint256 tokenId, address to) external {
        TradeLogic.settleProcess(
            tokenId,
            to,
            mToken,
            logisticsInfo
        );
    }

    function releaseMargin(uint256 tokenId) external {
        TradeLogic.releaseMarginProcess(
            tokenId,
            marginRate,
            feeRate,
            mToken,
            merchandiseInfo,
            users
        );
    }

    function refund(uint256 tokenId) external {
        TradeLogic.refundProcess(tokenId, logisticsInfo);
    }

    function returnMerchandise(
        uint256 tokenId,
        uint16 amount,
        string calldata logisticsNo,
        bytes32 deliveryAddress
    ) external {
        TradeLogic.returnMerchandiseProcess(
            tokenId,
            amount,
            logisticsNo,
            deliveryAddress,
            logisticsInfo,
            merchandiseInfo
        );
    }

    /**
        @dev management:setup global margin rate
     */
    function setMarginRate(uint16 newMarginRate) external onlyOwner {
        marginRate = newMarginRate;
    }

    function getMarginRate() external view returns (uint16) {
        return marginRate;
    }

    /**
        management:setup global fee rate
     */
    function setFeeRate(uint16 newFeeRate) external onlyOwner {
        feeRate = newFeeRate;
    }

    function getFeeRate() external view returns (uint16) {
        return feeRate;
    }

    /**
        @dev management:setup margin rate on user
     */
    function setUserMarginRate(address user, uint16 newMarginRate)
        external
        onlyOwner
    {
        users[user].marginRate = newMarginRate;
    }

    function getUserMarginRate(address user) external view returns (uint16) {
        return users[user].marginRate;
    }

    /**
        @dev management:setup fee rate on user
     */
    function setUserFeeRate(address user, uint16 newFeeRate)
        external
        onlyOwner
    {
        users[user].feeRate = newFeeRate;
    }

    function getUserFeeRate(address user) external view returns (uint16) {
        return users[user].feeRate;
    }
}
