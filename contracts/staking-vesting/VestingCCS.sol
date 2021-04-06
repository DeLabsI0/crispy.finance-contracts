// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


/*
    General Description:
        Simple vesting contract with linear vesting schedule. Tokens distributed
        per second remains constant.

    Owner:
        The owner acts as the arbitrar of the contract. The owner may update the
        beneficiary and drain the contract of its funds. This should either be a
        multi-sig contract, some voting mechanism or set to a contract that
        disallows draining to prevent premature unlocking of tokens.

    Beneficiary:
        Address to which pending rewards are sent.
*/
contract VestingCCS is Ownable {
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
    event Drain(address indexed drainedBeneficiary, address indexed drainingTo);

    constructor(
        IERC20 token_,
        uint256 vestingStart,
        uint256 cliff_,
        uint256 vestingEnd_,
        address beneficiary_
    ) Ownable() {
        require(vestingEnd_ > vestingStart, "CCS: End not after start");
        require(cliff_ < vestingEnd_, "CCS: Cliff must be before end");
        token = token_;
        lastRelease = vestingStart;
        cliff = cliff_;
        vestingEnd = vestingEnd_;
        beneficiary = beneficiary_;
        emit BeneficiaryUpdated(address(0), beneficiary_);
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "CCS: Not beneficary");
        _;
    }

    function drain(address recipient) external onlyOwner {
        uint256 remainingTokens = sync(false);
        _withdrawTokens(recipient, remainingTokens);
        address prevBeneficiary = _setBeneficiary(recipient);
        emit Drain(prevBeneficiary, recipient);
    }

    function changeBeneficiary(address newBeneficiary) external onlyOwner {
        sync(false);
        _setBeneficiary(newBeneficiary);
    }

    function pendingTokens() public view returns(uint256) {
        if (block.timestamp < cliff) {
            return uint256(0);
        }
        if (block.timestamp < vestingEnd) {
            uint256 timeSinceLastRelease = block.timestamp - lastRelease;
            uint256 totalTime = vestingEnd - lastRelease;
            return totalStillVested * timeSinceLastRelease / totalTime;
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
            stillVested -= pendingTokens_;
            failed = false;
        }
        uint256 curBalance = token.balanceOf(address(this));
        if (curBalance != stillVested) {
            emit Deposit(curBalance - stillVested);
            stillVested = curBalance;
            failed = false;
        }
        totalStillVested = stillVested;
        require(!revertOnFail || !failed, "CCS: Failed to sync");
        return stillVested;
    }

    function _setBeneficiary(address newBeneficiary) internal returns(address) {
        address prevBeneficiary = beneficiary;
        beneficiary = newBeneficiary;
        emit BeneficiaryUpdated(prevBeneficiary, newBeneficiary);
        return prevBeneficiary;
    }

    function _withdrawTokens(address recipient, uint256 amount) internal {
        token.safeTransfer(recipient, amount);
        emit Withdraw(recipient, amount);
    }
}
