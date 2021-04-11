// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./LoanBase.sol";

abstract contract BasicLoan is LoanBase, Initializable {
    uint256 public constant SCALE = 1e18;
    IERC20 public token;

    // payment tracking properties
    uint256 internal lastDebt; // debt at last update
    uint256 public interestRate; // scaled by SCALE
    uint256 public paymentGap; // time between payments
    uint256 public lastPayment; // time of last payment gap beginning
    uint256 public accountedPayments; // amount that has already been repayed

    function init(
        IERC20 _token,
        uint256 _interestRate,
        uint256 _paymentGap,
        uint256 _initialDebt
    )
        external initializer
    {
        token = _token;
        interestRate = _interestRate;
        paymentGap = _paymentGap;
        lastDebt = _initialDebt;
        lastPayment = block.timestamp;
    }

    function sync() public override virtual onlyWhen(Status.RUNNING) {
        super.sync();
        if (status == Status.RUNNING) {
            uint256 currentBalance = token.balanceOf(address(this));
            lastDebt = totalDebt() + accountedPayments - currentBalance;
            accountedPayments = currentBalance;
            uint256 excess = (block.timestamp - lastPayment) % paymentGap;
            lastPayment = block.timestamp - excess;
        }
    }

    function minimumOwedPayment() public view virtual returns(uint256);

    function totalDebt() public view virtual returns(uint256) {
        uint256 accruedDebt = lastDebt * SCALE;
        uint256 accruingPeriods = (lastPayment - block.timestamp) / paymentGap + 1;
        uint256 accInterestRate = SCALE + interestRate;
        while (accruingPeriods > 0) {
            if (accruingPeriods & 1 == 1) {
                accruedDebt = accruedDebt * accInterestRate / SCALE;
            }
            accInterestRate = accInterestRate * accInterestRate / SCALE;
            accruingPeriods /= 2;
        }
        return accruedDebt / SCALE;
    }

    function obligationPresent() public view virtual override returns(bool) {
        return lastPayment + paymentGap <= block.timestamp;
    }

    function obligationMet() public view virtual override returns(bool) {
        uint256 newPayment = token.balanceOf(address(this)) - accountedPayments;
        return newPayment >= minimumOwedPayment();
    }

    function noFutureObligations() public view virtual override returns(bool) {
        return token.balanceOf(address(this)) >= totalDebt();
    }
}
