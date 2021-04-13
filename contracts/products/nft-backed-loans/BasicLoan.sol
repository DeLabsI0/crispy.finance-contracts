// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../general/IRoleRegistry.sol";
import "./LoanBase.sol";

abstract contract BasicLoan is LoanBase, Initializable {
    uint256 public constant SCALE = 1e18;
    // keccak256('crispy.BasicLoan.lender')
    bytes32 public constant LENDER_ROLE =
        0xe6cdd4495653abf784e86ec538a7ecef650f98c56d189e4b82722f8052a14768;
    // keccak256('crispy.BasicLoan.debtor')
    bytes32 public constant DEBTOR_ROLE =
        0xf34c0e79980348ceab47d980685b84d238663d5d80021c43583ea08438f94c7d;

    IERC20 public token;
    IRoleRegistry public roleRegistry;

    // payment tracking properties
    uint256 internal lastDebt; // debt at last update
    uint256 public interestRate; // scaled by SCALE
    uint256 public paymentGap; // time between payments
    uint256 public lastPayment; // time of last payment gap beginning
    uint256 public accountedPayments; // amount that has already been repayed

    function init(
        IERC20 _token,
        IRoleRegistry _roleRegistry,
        address _lender,
        address _debtor,
        uint256 _interestRate,
        uint256 _paymentGap,
        uint256 _initialDebt
    )
        external initializer
    {
        token = _token;
        roleRegistry = _roleRegistry;
        _roleRegistry.registerRole(LENDER_ROLE, _lender);
        _roleRegistry.registerRole(DEBTOR_ROLE, _debtor);
        interestRate = _interestRate;
        paymentGap = _paymentGap;
        lastDebt = _initialDebt;
        lastPayment = block.timestamp;
    }

    modifier onlyRole(bytes32 _role) {
        require(
            roleRegistry.getRoleOwner(_role) == msg.sender,
            "BasicLoan: Missing role"
        );
        _;
    }

    function minimumOwedPayment() public view virtual returns(uint256);

    function totalDebt() public view virtual returns(uint256) {
        return _getFutureDebt(passedPeriods());
    }

    function passedPeriods() public view virtual returns(uint256) {
        return (block.timestamp - lastPayment) / paymentGap;
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

    function _getFutureDebt(uint256 _accruingPeriods)
        internal view virtual returns(uint256)
    {
        uint256 accruedDebt = lastDebt * SCALE;
        uint256 accInterestRate = SCALE + interestRate;
        while (_accruingPeriods > 0) {
            if (_accruingPeriods & 1 == 1) {
                accruedDebt = accruedDebt * accInterestRate / SCALE;
            }
            accInterestRate = accInterestRate * accInterestRate / SCALE;
            _accruingPeriods /= 2;
        }
        return accruedDebt / SCALE;
    }

    function _fulfillObligation() internal virtual override {
        uint256 minimumOwedPayment_ = minimumOwedPayment();
        lastDebt = totalDebt() - minimumOwedPayment_;
        accountedPayments += minimumOwedPayment_;
        lastPayment += passedPeriods() * paymentGap;
    }
}
