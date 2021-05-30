// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

abstract contract LoanBase {
    enum Status {
        RUNNING,
        COMPLETE,
        DEFAULT
    }
    Status internal status;

    event StatusChanged(Status prevStatus, Status newStatus);

    modifier onlyWhenStatus(Status _requiredStatus) {
        require(status == _requiredStatus, "LoanBase: Incorrect status");
        _;
    }

    function _sync() internal virtual onlyWhenStatus(Status.RUNNING) {
        if (_obligationPresent()) {
            if (_fulfillObligation()) {
                if (!_futureObligations()) {
                    _onComplete();
                }
            } else {
                _onDefault();
            }
        } else if (!_futureObligations()) {
            _onComplete();
        }
    }

    function _obligationPresent() internal virtual returns(bool);
    function _fulfillObligation() internal virtual returns(bool);
    function _futureObligations() internal virtual returns(bool);

    function _onDefault() internal virtual {
        _setStatus(Status.DEFAULT);
    }

    function _onComplete() internal virtual {
        _setStatus(Status.COMPLETE);
    }

    function _setStatus(Status _newStatus) internal virtual {
        Status prevStatus = status;
        status = _newStatus;
        emit StatusChanged(prevStatus, _newStatus);
    }
}
