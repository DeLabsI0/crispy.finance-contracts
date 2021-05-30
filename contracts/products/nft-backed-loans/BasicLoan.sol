// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./LoanBase.sol";

abstract contract BasicLoan is LoanBase, Initializable {
    uint256 public constant SCALE = 1e18; 

    // payment tracking properties
    uint256 internal lastDebt; // debt at last update
    uint256 public interestRate; // scaled by SCALE
    uint256 public paymentGap; // time between payments
    uint256 public lastPayment; // time of last payment gap beginning

    // function init(
    //     uint256 _interestRate,
    //     uint256 _paymentGap,
    //     uint256 _initialDebt
    // )
    //     external initializer
    // {
    //     interestRate = _interestRate;
    //     paymentGap = _paymentGap;
    //     lastDebt = _initialDebt;
    //     lastPayment = block.timestamp;
    // }
    //
    // function minimumOwedPayment() public view virtual returns(uint256);
    //
    // function totalDebt() public view virtual returns(uint256) {
    //     return _getFutureDebt(passedPeriods());
    // }
    //
    // function passedPeriods() public view virtual returns(uint256) {
    //     return (block.timestamp - lastPayment) / paymentGap;
    // }
    //
    // function obligationPresent() public view virtual override returns(bool) {
    //     return lastPayment + paymentGap <= block.timestamp;
    // }
    //
    // function obligationMet() public view virtual override returns(bool) {
    //     uint256 newPayment = token.balanceOf(address(this)) - accountedPayments;
    //     return newPayment >= minimumOwedPayment();
    // }
    //
    // function noFutureObligations() public view virtual override returns(bool) {
    //     return token.balanceOf(address(this)) >= totalDebt();
    // }
    //
    // function _getFutureDebt(uint256 _accruingPeriods)
    //     internal view virtual returns(uint256)
    // {
    //     uint256 accruedDebt = lastDebt * SCALE;
    //     uint256 accInterestRate = SCALE + interestRate;
    //     while (_accruingPeriods > 0) {
    //         if (_accruingPeriods & 1 == 1) {
    //             accruedDebt = accruedDebt * accInterestRate / SCALE;
    //         }
    //         accInterestRate = accInterestRate * accInterestRate / SCALE;
    //         _accruingPeriods /= 2;
    //     }
    //     return accruedDebt / SCALE;
    // }
    //
    // function _fulfillObligation() internal virtual override {
    //     uint256 minimumOwedPayment_ = minimumOwedPayment();
    //     lastDebt = totalDebt() - minimumOwedPayment_;
    //     accountedPayments += minimumOwedPayment_;
    //     lastPayment += passedPeriods() * paymentGap;
    // }
}
