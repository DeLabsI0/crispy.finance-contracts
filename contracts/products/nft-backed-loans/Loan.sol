// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILoanOwnerRegistry.sol";
import "./ILoan.sol";

contract Loan is ILoan, Initializable, Ownable {
    using SafeERC20 for IERC20;

    // core properties
    ILoanOwnerRegistry public override registry;
    IERC20 public token;
    Status public override status;
    uint256 public constant SCALE = 1e18;

    // payment tracking properties
    uint256 public debt;
    uint256 public interest; // scaled by SCALE
    uint256 public paymentGap; // time between payments
    uint256 public lastPayment; // time of last payment gap beginning

    bytes32 public override tokenUtid;

    function init(
        IERC20 _token,
        uint256 _principal
    )
        external override initializer
    {
        registry = ILoanOwnerRegistry(msg.sender);
        token = _token;
        principal = _principal;
    }

    modifier onlyWhen(Status _requiredStatus) {
        require(status == _requiredStatus, "Loan: Incorrect status");
        _;
    }

    function onFunding() external onlyWhen(Status.COLLATERLIZED) {
        require(msg.sender == address(registry), "Loan: Not registry");
        token.transfer(owner(), principal);
        debt = principal;
        lastPayment = block.timestamp;
        _setStatus(Status.CLOSED);
    }

    function _setStatus(Status _newStatus) internal {
        Status prevStatus = status;
        status = _newStatus;
        emit StatusChanged(prevStatus, _newStatus);
    }
}
