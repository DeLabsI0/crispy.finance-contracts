// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "../market/IDepositController.sol";

interface ILoan is IDepositController {
    enum Status {
        OPEN,
        COLLATERLIZED,
        CLOSED,
        COMPLETE,
        DEFAULTED
    }

    event StatusChanged(Status prevStatus, Status newStatus);
    event DebtorChanged(address indexed prevDebtor, address indexed newDebtor);

    function init(address _debtor, address _lender) external;
    function debtor() external view returns(address);
    function tokenUtid() external view returns(bytes32);
    function registry() external view returns(address);
    function status() external view returns(Status);

    function onFunding() external;
}
