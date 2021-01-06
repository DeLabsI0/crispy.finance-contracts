// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./FeeMath.sol";
import "./IFeeRecipient.sol";

abstract contract FeeTaker is Ownable {
    IERC20 public mainToken;
    uint192 internal _fee;

    event FeeSet(uint192 newFee);
    event FeeCollected(uint256 feeAmount);

    constructor(uint192 startFee, IERC20 mainToken_) Ownable() {
        _setFee(startFee);
        mainToken = mainToken_;
    }

    modifier feeMatch(uint192 expectedFee) {
        require(expectedFee == _fee, 'Fee has changed');
        _;
    }

    function setFee(uint192 newFee) external onlyOwner {
        _setFee(newFee);
    }

    function fee() public view returns(uint256) {
        return _fee;
    }

    function takeFee(uint256 amount) internal returns (uint256 remainder) {
        (remainder, uint256 collectedFee) = FeeMath.splitToFee(amount, _fee);
        _accountFee(collectedFee);
        return remainder;
    }

    function _accountFee(uint256 collectedFee) internal {
        mainToken.transfer(owner(), collectedFee);
        if (Address.isContract(owner())) {
            IFeeRecipient(owner()).onFeeReceived(collectedFee);
        }

        emit FeeCollected(collectedFee);
    }

    function _setFee(uint192 newFee) internal {
        require(newFee <= SafeQMath.ONE, 'Fee may not be higher than 100%');
        _fee = newFee;
        emit FeeSet(newFee);
    }
}
