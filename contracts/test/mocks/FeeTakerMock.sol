// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../lib/FeeTaker.sol";

contract FeeTakerMock is FeeTaker {
    using SafeERC20 for IERC20;

    constructor(uint256 _fee) FeeTaker(_fee) { }

    function depositEthFee() external payable {
        _accountFee(msg.value, NATIVE);
    }

    function depositERC20Fee(uint256 _amount, IERC20 _token) external {
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        _accountFee(_amount, _token);
    }

    function addFeeToTotal(uint256 _total, IERC20 _token) external {
        uint256 afterFeeTotal = _addFeeForTotal(_total, _token);
        _token.safeTransferFrom(msg.sender, address(this), afterFeeTotal);
        _token.safeTransfer(msg.sender, _total);
    }

    function takeFeeFrom(uint256 _amount, IERC20 _token) external {
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 leftover = _takeFeeFrom(_amount, _token);
        _token.safeTransfer(msg.sender, leftover);
    }

    function checkFeeEqual(uint256 _fee) external view {
        _checkFeeEqual(_fee);
    }

    function checkFeeAtMost(uint256 _maxFee) external view {
        _checkFeeAtMost(_maxFee);
    }
}
