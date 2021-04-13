// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "./BasicLoan.sol";

contract InterestOnlyLoan is BasicLoan {
    function minimumOwedPayment() public view virtual override returns(uint256) {
        return totalDebt() - lastDebt;
    }
}
