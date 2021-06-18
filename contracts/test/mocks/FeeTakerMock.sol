// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../lib/FeeTaker.sol";

contract FeeTakerMock is FeeTaker {
    using SafeERC20 for IERC20;

    constructor(uint256 _fee) FeeTaker(_fee) { }

    function depositEthFee() external payable {
        _accountFee(IERC20(address(0)), msg.value);
    }

    function depositERC20Fee(IERC20 _token, uint256 _amount) external {
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        _accountFee(_token, _amount);
    }

    function takeFeeFrom(IERC20 _token, uint256 _amount) external {
        _token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 leftover = _takeFee(_token, _amount);
        _token.safeTransfer(msg.sender, leftover);
    }

    function checkFeeAtMost(uint256 _maxFee) external view {
        _checkFeeAtMost(_maxFee);
    }
}
