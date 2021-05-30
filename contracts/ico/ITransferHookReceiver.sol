// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

interface ITransferHookReceiver {
    function onTransfer(
        address executor,
        address from,
        address to,
        uint256 amount
    ) external;
}
