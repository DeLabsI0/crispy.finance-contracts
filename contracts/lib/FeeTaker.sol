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
    mapping(IERC20 => uint256) internal _accountedFees;

    event FeeSet(address indexed setter, uint256 indexed fee);
    event AccountedFee(IERC20 indexed token, uint256 amount);
    event FeeWithdrawn(
        IERC20 indexed token,
        address indexed withdrawer,
        address indexed recipient,
        uint256 amount
    );

    constructor(uint256 _fee) Ownable() {
        _setFee(_fee);
    }

    function withdrawFee(IERC20 _token, address _recipient, uint256 _amount)
        external virtual onlyOwner
    {
        uint256 _accountedFee = _accountedFees[_token];
        require(_accountedFee >= _amount, "FeeTaker: insufficient fees");
        unchecked {
            _accountedFees[_token] = _accountedFee - _amount;
        }
        if (address(_token) == address(0)) {
            payable(_recipient).sendValue(_amount);
        } else {
            _token.safeTransfer(_recipient, _amount);
        }
        emit FeeWithdrawn(_token, msg.sender, _recipient, _amount);
    }

    function setFee(uint256 _fee) external onlyOwner {
        _setFee(_fee);
    }

    function _checkFeeAtMost(uint256 _maxFee) internal view {
        require(_maxFee >= fee, "FeeTaker: fee too high");
    }

    function _takeFee(IERC20 _token, uint256 _totalAmount)
        internal virtual returns (uint256)
    {
        uint256 fee_ = fee;
        if (fee_ == 0) return _totalAmount;
        uint256 takenFee = _totalAmount * fee_ / SCALE;
        _accountFee(_token, takenFee);
        return _totalAmount - takenFee;
    }

    function _accountFee(IERC20 _token, uint256 _amount) internal virtual {
        _accountedFees[_token] += _amount;
        emit AccountedFee(_token, _amount);
    }

    function _setFee(uint256 _fee) internal virtual {
        require(_fee <= SCALE, "FeeTaker: fee too high");
        fee = _fee;
        emit FeeSet(msg.sender, _fee);
    }
}
