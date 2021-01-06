// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

interface IFeeRecipient {
    function onFeeReceived(uint256 feeCollected) external;
}
