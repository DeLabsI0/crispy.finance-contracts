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
    uint256 public totalStillVested;
    uint256 public lastRelease;
    uint256 public immutable cliff;
    uint256 public immutable vestingEnd;

    event BeneficiaryUpdated(
        address indexed prevBeneficiary,
        address indexed newBeneficiary
    );
    event Withdraw(address indexed recipient, uint256 amount);
    event Deposit(uint256 amount);

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

    function drain(address recipient) external onlyOwner {
        uint256 remainingTokens = sync(false);
        _withdrawTokens(recipient, remainingTokens);
    }

    function changeBeneficiary(address newBeneficiary) external onlyOwner {
        sync(false);
        address prevBeneficiary = beneficiary;
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
            return totalStillVested.mul(timeSinceLastRelease).div(totalTime);
        } else {
            return token.balanceOf(address(this));
        }
    }

    function sync(bool revertOnFail) public returns(uint256) {
        uint256 pendingTokens_ = pendingTokens();
        uint256 stillVested = totalStillVested;
        bool failed = true;
        if (pendingTokens_ > 0) {
            lastRelease = block.timestamp;
            _withdrawTokens(beneficiary, pendingTokens_);
            stillVested = stillVested.sub(pendingTokens_);
            failed = false;
        }
        uint256 curBalance = token.balanceOf(address(this));
        if (curBalance != stillVested) {
            emit Deposit(curBalance.sub(stillVested));
            stillVested = curBalance;
            failed = false;
        }
        totalStillVested = stillVested;
        require(!revertOnFail || !failed, "CS: Failed to sync");
        return stillVested;
    }

    function _withdrawTokens(address recipient, uint256 amount) internal {
        token.safeTransfer(recipient, amount);
        emit Withdraw(recipient, amount);
    }
}
