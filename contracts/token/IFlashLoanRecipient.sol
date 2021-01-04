// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IFlashLoanRecipient {
    function onFlashLoanReady(
        uint256 expectedReturnAmount,
        bytes memory callbackData
    ) external;
}
