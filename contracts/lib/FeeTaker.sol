// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract FeeTaker is Ownable {
    using Address for address payable;
    using SafeERC20 for IERC20;

    uint256 public constant SCALE = 1e18;
    uint256 public fee;
    mapping(IERC20 => uint256) public accountedFees;

    IERC20 internal constant NATIVE = IERC20(address(0));

    event FeeSet(address indexed setter, uint256 indexed fee);
    event AccountedFee(IERC20 indexed token, uint256 amount);
    event FeesWithdrawn(
        IERC20 indexed token,
        address indexed withdrawer,
        address indexed recipient,
        uint256 amount
    );

    constructor(uint256 _fee) Ownable() {
        _setFee(_fee);
    }

    function withdrawFeesTo(address _recipient, uint256 _amount, IERC20 _token)
        external virtual onlyOwner
    {
        uint256 _accountedFee = accountedFees[_token];
        require(_accountedFee >= _amount, "FeeTaker: Insufficient fees");
        unchecked {
            accountedFees[_token] = _accountedFee - _amount;
        }
        if (_token == NATIVE) {
            emit FeesWithdrawn(_token, msg.sender, _recipient, _amount);
            payable(_recipient).sendValue(_amount);
        } else {
            _token.safeTransfer(_recipient, _amount);
            emit FeesWithdrawn(_token, msg.sender, _recipient, _amount);
        }
    }

    function setFee(uint256 _fee) external virtual onlyOwner {
        _setFee(_fee);
    }

    function _checkFeeAtMost(uint256 _maxFee) internal virtual view {
        require(_maxFee >= fee, "FeeTaker: Fee too high");
    }

    function _checkFeeEqual(uint256 _fee) internal virtual view {
        require(_fee == fee, "FeeTaker: Wrong fee");
    }

    function _addFeeForTotal(uint256 _totalAmount, IERC20 _token)
        internal virtual returns (uint256)
    {
        uint256 fee_ = fee;
        if (fee_ == 0) return _totalAmount;
        uint256 feeToTake = _totalAmount * fee_ / (SCALE - fee_);
        _accountFee(feeToTake, _token);
        return _totalAmount + feeToTake;
    }

    function _takeFeeFrom(uint256 _totalAmount, IERC20 _token)
        internal virtual returns (uint256)
    {
        uint256 fee_ = fee;
        if (fee_ == 0) return _totalAmount;
        uint256 feeToTake = _totalAmount * fee_ / SCALE;
        _accountFee(feeToTake, _token);
        return _totalAmount - feeToTake;
    }

    function _accountFee(uint256 _fee, IERC20 _token) internal virtual {
        accountedFees[_token] += _fee;
        emit AccountedFee(_token, _fee);
    }

    function _setFee(uint256 _fee) internal virtual {
        require(_fee <= SCALE, "FeeTaker: Fee above 100%");
        fee = _fee;
        emit FeeSet(msg.sender, _fee);
    }
}
