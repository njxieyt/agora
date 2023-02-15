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
        // Unit: percentage with 2 decimal(default 0.1%)
        marginRate = 10;
    }

    function sell(
        uint16 amount,
        uint256 uintPrice,
        string calldata newUri
    ) external payable returns (uint256) {
        TradeLogic.sellProcess(
            ++_currentTokenId,
            uintPrice,
            amount,            
            marginRate,
            feeRate,
            newUri,            
            mToken,
            merchandiseInfo,
            users
        );
        // Contract management mToken 
        mToken.setApprovalForAll(address(this), true);
        return _currentTokenId;
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

    function delivered(uint256 tokenId, address to) external {
        TradeLogic.deliveredProcess(
            tokenId,
            to,
            logisticsLookup,
            logisticsInfo
        );
    }

    function settlement(uint256 tokenId, address to) external {
        TradeLogic.settlementProcess(
            tokenId,
            payable(to),
            mToken,
            merchandiseInfo,
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

    function getFeeRate() external view returns(uint16) {
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
    function setUserFeeRate(address user, uint16 newFeeRate) external onlyOwner {
        users[user].feeRate = newFeeRate;
    }

    function getUserFeeRate(address user) external view returns (uint16) {
        return users[user].feeRate;
    }
}
