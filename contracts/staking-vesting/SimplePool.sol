// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "safe-qmath/contracts/SafeQMath.sol";
import "../utils/fee/IFeeRecipient.sol";

contract SimplePool is Ownable, IFeeRecipient {
    using SafeMath for uint256;
    using SafeQMath for uint192;

    address internal _feeCollector;
    IERC20 internal _stakeToken;
    IERC20 internal _feeToken;

    uint192 internal _rewardsAccumulator;
    uint256 internal _totalStaked;

    struct StakeData {
        bool staked;
        uint256 stakeAmount;
        uint192 accumulator;
    }

    mapping(address => StakeData) internal _userStakeData;

    event StakeStarted(
        address indexed staker,
        uint192 accumulator,
        uint256 amount
    );

    constructor(
        address feeCollector_,
        IERC20 stakeToken_,
        IERC20 feeToken_
    ) Ownable() {
        _feeCollector = feeCollector_;
        _stakeToken = stakeToken_;
        _feeToken = feeToken_;
    }

    function onFeeReceived(uint256 collectedFee) external override {
        require(msg.sender == _feeCollector, 'SimplePool: Access denied');

        uint192 accrued = SafeQMath.intToQ(collectedFee).qdiv(SafeQMath.intToQ(_totalStaked));

        _rewardsAccumulator = _rewardsAccumulator.qadd(accrued);
    }

    function stake(uint256 amount) external {
        _stakeToken.transferFrom(msg.sender, address(this), amount);
        _totalStaked = _totalStaked.add(amount);

        StakeData storage userStake = _userStakeData[msg.sender];

        if (userStake.staked) {
            _claimRewards();
        } else {
            userStake.staked = true;
        }

        userStake.stakeAmount = userStake.stakeAmount.add(amount);
        _resetAccumulator();
    }

    function unstake(uint256 amount) external {
        claimRewards();

        StakeData storage userStake = _userStakeData[msg.sender];
        uint256 stakeAmount = userStake.stakeAmount;
        require(stakeAmount >= amount, "SimplePool: insufficient funds");
        stakeAmount -= amount;
        if (stakeAmount == 0) {
            userStake.staked = false;
        }
        userStake.stakeAmount = stakeAmount;
    }

    function claimRewards() public {
        _claimRewards();
        _resetAccumulator();
    }

    function _claimRewards() internal {
        StakeData storage userStake = _userStakeData[msg.sender];
        uint192 accumulator = userStake.accumulator.qsub(_rewardsAccumulator);
        uint256 accruedRewards = accumulator.qmul(SafeQMath.intToQ(userStake.stakeAmount)).qToIntLossy();
        _feeToken.transfer(msg.sender, accruedRewards);
    }

    function _resetAccumulator() internal {
        _userStakeData[msg.sender].accumulator = _rewardsAccumulator;
    }
}
