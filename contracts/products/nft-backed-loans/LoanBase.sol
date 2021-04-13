// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "./ILoanBase.sol";

abstract contract LoanBase is ILoanBase {
    Status public override status;

    modifier onlyWhen(Status _requiredStatus) {
        require(status == _requiredStatus, "Loan: Incorrect status");
        _;
    }

    function sync() public override virtual onlyWhen(Status.RUNNING) {
        if (obligationPresent()) {
            if (!obligationMet()) {
                _setStatus(Status.DEFAULT);
            } else if (noFutureObligations()) {
                _setStatus(Status.COMPLETE);
            } else {
                _fulfillObligation();
            }
        }
    }

    function obligationPresent() public view virtual override returns(bool);
    function obligationMet() public view virtual override returns(bool);
    function noFutureObligations() public view virtual override returns(bool);
    function _fulfillObligation() internal virtual;

    function _setStatus(Status _newStatus) internal virtual {
        Status prevStatus = status;
        status = _newStatus;
        emit StatusChanged(prevStatus, _newStatus);
    }
}
