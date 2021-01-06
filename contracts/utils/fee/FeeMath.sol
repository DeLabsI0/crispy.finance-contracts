// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import 'safe-qmath/contracts/SafeQMath.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

library FeeMath {
    using SafeQMath for uint192;
    using SafeMath for uint256;

    function splitToFee(uint256 amount, uint192 fee)
        internal
        pure
        returns (uint256 leftOver, uint256 resFee)
    {
        resFee = fee.qmul(SafeQMath.intToQ(amount)).qToIntLossy();
        leftOver = amount.sub(resFee);
    }
}
