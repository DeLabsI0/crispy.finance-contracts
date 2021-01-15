// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../ico/CrispyToken.sol";
import "../Treasury.sol";

contract SimpleMVG {
    using SafeMath for uint256;

    CrispyToken public constant CRISPY_TOKEN = CrispyToken(/* CRUNCH address */ address(0));
    Treasury public constant TREASURY = Treasury(/* Treasury address */ address(0));

    uint256 public constant ONE = 100000;

    uint256 public constant ACTIVATION_THRESHHOLD = 6000; // 6% of available supply
    uint256 public constant ACTIVATION_TAX = 5000; // 5% of ACTIVATION_THRESHHOLD

    uint256 public constant VOTE_PERIOD = 7 days;
    uint256 public constant ACCEPTANCE_THRESHHOLD = 60000; // 60%
    uint256 public constant FINISH_REWARD = 1000; // 1% of ACTIVATION_TAX

    bytes public callData;
    uint256 public activatedOn;
    bool public finished;
    uint256 public finishReward;
    uint256 public actionId;

    enum Vote { EMPTY, FOR, AGAINST }
    struct Voter {
        uint256 votesPlaced;
        uint256 actionId;
        Vote vote;
    }

    mapping(Vote => uint256) public voteCount;
    mapping(address => Voter) public voters;

    event ActionInitiated(
        bytes32 indexed callDataHash,
        uint256 indexed actionId,
        uint256 activatedOn,
        uint256 votingEndsOn,
        bytes callData
    );

    event ActionFinished(
        bytes32 indexed callDataHash,
        uint256 indexed actionId,
        uint256 activatedOn,
        uint256 votingEndedOn,
        bytes callData,
        bool executed,
        bool successfullyExecuted
    );

    constructor() {
        finished = true;
    }

    function initiateAction(bytes calldata callData_) external {
        require(callData.length > 0, "MVG: Cannot be empty call");
        require(finished, "MVG: Previous action not done");
        uint256 activationThreshhold = _fracMul(totalAvailableVotes(), ACTIVATION_THRESHHOLD);
        require(
            CRISPY_TOKEN.balanceOf(msg.sender) >= activationThreshhold,
            "MVG: Below capital requirement"
        );

        _tax(activationThreshhold);

        callData = callData_;
        uint256 activatedOn_ = block.timestamp;

        activatedOn = activatedOn_;
        finished = false;
        voteCount[Vote.FOR] = 0;
        voteCount[Vote.AGAINST] = 0;

        emit ActionInitiated(
            keccak256(callData_),
            actionId++,
            activatedOn_,
            activatedOn_.add(VOTE_PERIOD),
            callData_
        );
    }

    function voteOn(Vote vote) external {
        if (checkDone()) return;
    }

    function totalAvailableVotes() public view returns(uint256) {
        uint256 treasuryReserves = CRISPY_TOKEN.balanceOf(address(TREASURY));
        return CRISPY_TOKEN.totalSupply().sub(treasuryReserves);
    }

    function checkDone() public returns(bool) {
        require(!finished, "MVG: No Action currently active");

        if (block.timestamp <= activatedOn.add(VOTE_PERIOD)) {
            return false;
        }

        _executeWill();
        CRISPY_TOKEN.transfer(msg.sender, finishReward);
        return true;
    }

    function _executeWill() internal {
        uint256 votesFor = voteCount[Vote.FOR];
        uint256 votesAgainst = voteCount[Vote.AGAINST];

        uint256 votesForFraction = _fracDiv(votesFor, votesAgainst.add(votesFor));

        bool accepted = votesForFraction >= ACCEPTANCE_THRESHHOLD;
        bool successfullyExecuted = false;

        if (accepted) {
            (successfullyExecuted,) = address(TREASURY).call(callData);
        }

        finished = true;
        emit ActionFinished(
            keccak256(callData),
            actionId,
            activatedOn,
            block.timestamp,
            callData,
            accepted,
            successfullyExecuted
        );
    }

    function _tax(uint256 amountToTax) internal {
        uint256 totalToTax = _fracMul(amountToTax, ACTIVATION_TAX);
        uint256 finishReward_ = _fracMul(totalToTax, FINISH_REWARD);

        CRISPY_TOKEN.transferFrom(msg.sender, address(TREASURY), totalToTax.sub(finishReward_));
        CRISPY_TOKEN.transferFrom(msg.sender, address(this), finishReward_);

        finishReward = finishReward_;
    }

    function _fracMul(uint256 intX, uint256 fracY) internal pure returns(uint256) {
        return intX.mul(fracY).div(ONE);
    }

    function _fracDiv(uint256 intX, uint256 intY) internal pure returns(uint256) {
        return intX.mul(ONE).div(intY);
    }
}
