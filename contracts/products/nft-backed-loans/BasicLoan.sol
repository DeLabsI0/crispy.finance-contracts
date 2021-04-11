// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./LoanBase.sol";

abstract contract BasicLoan is LoanBase {
    IERC20 public token;
    Status public override status;
    uint256 public constant SCALE = 1e18;

    // payment tracking properties
    uint256 public interestRate; // scaled by SCALE
    uint256 public paymentGap; // time between payments
    uint256 public lastPayment; // time of last payment gap beginning
    uint256 internal lastDebt; // debt at last update

    modifier onlyWhen(Status _requiredStatus) {
        require(status == _requiredStatus, "Loan: Incorrect status");
        _;
    }

    // function init(IERC20 _token)

    function closeLoan() external virtual onlyWhen(Status.LOCKED) {
        uint256 loanReserve = token.balanceOf(address(this));
        uint256 totalDebt_ = totalDebt();
        require(loanReserve >= totalDebt_, "LoanBase: Must payoff to close");
        _closeLoan(totalDebt_, Math.max(loanReserve, totalDebt_) - totalDebt_);
    }

    function minimumOwedPayment() public view virtual returns(uint256);

    function totalDebt() public view virtual returns(uint256) {
        uint256 accruedDebt = lastDebt * SCALE;
        uint256 passedPeriods = (lastPayment - block.timestamp) / paymentGap + 1;
        uint256 accInterestRate = SCALE + interestRate;
        while (passedPeriods > 0) {
            if (passedPeriods & 1 == 1) {
                accruedDebt = accruedDebt * accInterestRate / SCALE;
            }
            accInterestRate = accInterestRate * accInterestRate / SCALE;
            passedPeriods /= 2;
        }
        return accruedDebt / SCALE;
    }

    function _closeLoan(uint256 _lenderPayout, uint256 _debtorRefund)
        internal virtual;

    function _setStatus(Status _newStatus) internal {
        Status prevStatus = status;
        status = _newStatus;
        emit StatusChanged(prevStatus, _newStatus);
    }
}
