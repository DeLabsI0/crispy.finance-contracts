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
        IERC20 _token,
        uint256 _vestingStart,
        uint256 _cliff,
        uint256 _vestingEnd,
        address _beneficiary
    ) Ownable() {
        require(_vestingEnd > _vestingStart, "CCS: End not after start");
        require(_cliff < _vestingEnd, "CCS: Cliff must be before end");
        token = _token;
        lastRelease = _vestingStart;
        cliff = _cliff;
        vestingEnd = _vestingEnd;
        beneficiary = _beneficiary;
        emit BeneficiaryUpdated(address(0), _beneficiary);
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "CCS: Not beneficary");
        _;
    }

    function drain(address _recipient) external onlyOwner {
        uint256 remainingTokens = sync(false);
        _withdrawTokens(_recipient, remainingTokens);
        address prevBeneficiary = _setBeneficiary(_recipient);
        emit Drain(prevBeneficiary, _recipient);
    }

    function changeBeneficiary(address _newBeneficiary) external onlyOwner {
        sync(false);
        _setBeneficiary(_newBeneficiary);
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

    function sync(bool _revertOnFail) public returns(uint256) {
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
        require(!_revertOnFail || !failed, "CCS: Failed to sync");
        return stillVested;
    }

    function _setBeneficiary(address _newBeneficiary) internal returns(address) {
        address prevBeneficiary = beneficiary;
        beneficiary = _newBeneficiary;
        emit BeneficiaryUpdated(prevBeneficiary, _newBeneficiary);
        return prevBeneficiary;
    }

    function _withdrawTokens(address _recipient, uint256 _amount) internal {
        token.safeTransfer(_recipient, _amount);
        emit Withdraw(_recipient, _amount);
    }
}
