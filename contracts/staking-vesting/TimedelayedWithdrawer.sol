// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TimedelayedWithdrawer {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficary;
    uint256 public immutable minDelay;
    uint256 public immutable minExecutionDelay;

    enum Status { NON_EXISTANT, PENDING, CANCELLED, EXECUTED }

    struct Withdrawal {
        address recipient;
        uint256 amount;
        uint256 unlockTime;
        Status status;
    }

    Withdrawal[] public withdrawals;
    uint256 public scheduledTokens;

    event WithdrawalScheduled(
        address indexed recipient,
        uint256 indexed withdrawalIndex,
        uint256 amount,
        uint256 unlockTime
    );
    event WithdrawalExecuted(
        address indexed recipient,
        uint256 indexed withdrawalIndex,
        uint256 amount
    );
    event WithdrawalCancelled(
        address indexed recipient,
        uint256 indexed withdrawalIndex,
        uint256 amount
    );

    constructor(
        IERC20 _token,
        address _beneficiary,
        uint256 _minDelay,
        uint256 _minExecutionDelay
    ) {
        token = _token;
        beneficary = _beneficiary;
        minDelay = _minDelay;
        minExecutionDelay = _minExecutionDelay;
    }

    modifier onlyBeneficiary() {
        require(beneficary == msg.sender, "TdW: Not beneficary");
        _;
    }

    function scheduleWithdrawal(
        address _recipient,
        uint256 _amount,
        uint256 _unlockTime
    ) external onlyBeneficiary {
        require(_unlockTime - block.timestamp >= minDelay, "TdW: Unlock time too early");
        uint256 newlyScheduledTokens = scheduledTokens + _amount;
        require(newlyScheduledTokens <= token.balanceOf(address(this)), "TdW: Insufficient tokens");
        scheduledTokens = newlyScheduledTokens;
        withdrawals.push(Withdrawal({
            recipient: _recipient,
            amount: _amount,
            unlockTime: _unlockTime,
            status: Status.PENDING
        }));
        emit WithdrawalScheduled(
            _recipient,
            withdrawals.length - 1,
            _amount,
            _unlockTime
        );
    }

    function executeWithdrawal(uint256 _withdrawalIndex)
        external
        onlyBeneficiary
    {
        Withdrawal storage withdrawal = withdrawals[_withdrawalIndex];
        require(withdrawal.unlockTime <= block.timestamp, "TdW: Withdrawal not yet unlocked");

        if (block.timestamp <= withdrawal.unlockTime + minExecutionDelay) {
            require(withdrawal.status == Status.PENDING, "TdW: No withdrawal to execute");
            address recipient = withdrawal.recipient;
            uint256 amount = withdrawal.amount;
            scheduledTokens -= amount;
            withdrawal.status = Status.EXECUTED;
            token.safeTransfer(recipient, amount);
            emit WithdrawalExecuted(recipient, _withdrawalIndex, amount);
        } else {
            _cancelWithdrawal(_withdrawalIndex);
        }
    }

    function cancelWithdrawal(uint256 _withdrawalIndex) external onlyBeneficiary {
        _cancelWithdrawal(_withdrawalIndex);
    }

    function _cancelWithdrawal(uint256 _withdrawalIndex) internal {
        Withdrawal storage withdrawal = withdrawals[_withdrawalIndex];
        require(withdrawal.status == Status.PENDING, "TdW: No withdrawal to cancel");
        withdrawal.status = Status.CANCELLED;
        uint256 amount = withdrawal.amount;
        scheduledTokens -= amount;
        emit WithdrawalCancelled(withdrawal.recipient, _withdrawalIndex, amount);
    }
}
