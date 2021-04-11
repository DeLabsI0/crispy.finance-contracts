// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "./ILoanBase.sol";

abstract contract LoanBase is ILoanBase {
    enum Status {
        RUNNING,
        COMPLETE,
        DEFAULT
    }
    Status public override status;

    event StatusChanged(Status prevStatus, Status newStatus);

    modifier onlyWhen(Status _requiredStatus) {
        require(status == _requiredStatus, "Loan: Incorrect status");
        _;
    }

    function triggerNextStep() public virtual onlyWhen(Status.RUNNING) {
        if (obligationPresent()) {
            if (obligationMet()) {
                if (noFutureObligations()) _setStatus(Status.COMPLETE);
            } else _setStatus(Status.DEFAULT);
        }
    }

    function obligationPresent() public view virtual override returns(bool);
    function obligationMet() public view virtual override returns(bool);
    function noFutureObligations() public view virtual override returns(bool);

    function _setStatus(Status _newStatus) internal virtual {
        Status prevStatus = status;
        status = _newStatus;
        emit StatusChanged(prevStatus, _newStatus);
    }
}
