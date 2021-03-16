// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract CliffConstantStream is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public beneficiary;
    uint256 public toBeReleased;
    uint256 public lastRelease;
    uint256 public immutable cliff;
    uint256 public immutable vestingEnd;

    event BeneficiaryUpdated(
        address indexed prevBeneficiary,
        address indexed newBeneficiary
    );
    event Withdraw(address indexed recipient, uint256 amount);
    event Deposit(address indexed depositor, uint256 amount);

    constructor(
        IERC20 token_,
        uint256 vestingStart,
        uint256 cliff_,
        uint256 vestingEnd_,
        address beneficiary_
    ) Ownable() {
        require(vestingEnd_ > vestingStart, "CS: End not after start");
        require(cliff_ < vestingEnd_, "CS: Cliff must be before end");
        token = token_;
        lastRelease = vestingStart;
        cliff = cliff_;
        vestingEnd = vestingEnd_;
        beneficiary = beneficiary_;
        emit BeneficiaryUpdated(address(0), beneficiary_);
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "CS: Not beneficary");
        _;
    }

    function deposit(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        toBeReleased = toBeReleased.add(amount);
        emit Deposit(msg.sender, amount);
    }

    function sync(address recipient) external onlyBeneficiary {
        require(block.timestamp < vestingEnd, "CS: Vesting has already ended");
        _withdrawPending(recipient, false);
        uint256 currentBal = token.balanceOf(address(this));
        uint256 toBeReleased_ = toBeReleased;
        require(toBeReleased_ < currentBal, "CS: Balance already synced up");
        toBeReleased = currentBal;
        emit Deposit(address(0), currentBal - toBeReleased_);
    }

    function withdrawTokensTo(address recipient) external onlyBeneficiary {
        _withdrawPending(recipient, true);
    }

    function drain(address recipient) external onlyOwner {
        _withdrawPending(beneficiary, false);
        _withdrawTokens(recipient, token.balanceOf(address(this)));
    }

    function changeBeneficiary(address newBeneficiary) external onlyOwner {
        address prevBeneficiary = beneficiary;
        _withdrawPending(prevBeneficiary, false);
        beneficiary = newBeneficiary;
        emit BeneficiaryUpdated(prevBeneficiary, newBeneficiary);
    }

    function pendingTokens() public view returns(uint256) {
        if (block.timestamp < cliff) {
            return uint256(0);
        }
        if (block.timestamp < vestingEnd) {
            uint256 timeSinceLastRelease = block.timestamp.sub(lastRelease);
            uint256 totalTime = vestingEnd.sub(lastRelease);
            return toBeReleased.mul(timeSinceLastRelease).div(totalTime);
        } else {
            return token.balanceOf(address(this));
        }
    }

    function _withdrawPending(address beneficiary_, bool revertOnFail) internal {
        uint256 pendingTokens_ = pendingTokens();
        if (pendingTokens_ > 0) {
            lastRelease = block.timestamp;
            _withdrawTokens(beneficiary_, pendingTokens_);
            toBeReleased = toBeReleased.sub(pendingTokens_);
        } else {
            require(!revertOnFail, "CS: No pending tokens");
        }
    }

    function _withdrawTokens(address recipient, uint256 amount) internal {
        token.safeTransfer(recipient, amount);
        emit Withdraw(recipient, amount);
    }
}
