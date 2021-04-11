// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

interface ILoanBase {
    enum Status {
        RUNNING,
        COMPLETE,
        DEFAULT
    }

    event StatusChanged(Status prevStatus, Status newStatus);

    function sync() external;
    function status() external view returns(Status);
    function obligationPresent() external view returns(bool);
    function obligationMet() external view returns(bool);
    function noFutureObligations() external view returns(bool);
}
