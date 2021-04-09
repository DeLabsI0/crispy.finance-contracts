// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

interface IDepositController {
    function onTokenDeposit(
        address depositor,
        bytes32 utid,
        bytes calldata data
    ) external;
}
