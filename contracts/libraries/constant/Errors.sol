// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

library Errors {
    string public constant INSUFFICIENT_MARGIN = "1";
    string public constant URI_NOT_DEFINED = "2";
    string public constant INVALID_AMOUNT = "3";
    string public constant NOT_ENOUGH_ETH = "4";
    string public constant NO_ORDER = "5";
    string public constant ORDER_UNCOMPLETED = "6";
    string public constant MARGIN_BELOW_THRESHOLD = "7";
    string public constant NOT_ENOUGH_AVAILABLE_FEES = "8";
    string public constant LOGISTICS_PROCESSED = "9";
    string public constant AMOUNT_EXCEEDED = "10";
    string public constant NOT_ENOUGH_TIME = "11";
    string public constant RETURN_TIME_EXPIRED = "12";
    string public constant MERCHANDISE_RETURNED = "13";
    string public constant INSUFFICIENT_AMOUNT = "14";
    string public constant SETTLEMENT_PARTNER_IS_ONESELF = "15";
    string public constant ORDER_CANCELED = "16";
    string public constant CALLER_NOT_THE_OWNER = "17";
    string public constant INVALID_PRICE = "18";
}
