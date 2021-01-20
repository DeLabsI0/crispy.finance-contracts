// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../ico/CrispyToken.sol";
import "../Treasury.sol";

/*
    MVG (Minimum Viable Governance)

    Simple governance contract governing the treasury. Can only send arbitrary
    transactions to a single address (in this case the treasury). Only one
    action can be created and voted on at a time.

    In order to upgrade the governance a proposal needs to be passed to transfer
    ownership of the treasury to a new governance contract.
*/
contract MVG {
    using SafeMath for uint256;

    CrispyToken public immutable CRISPY_TOKEN;
    Treasury public immutable TREASURY;

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
    uint256 public actionNonce;

    enum Vote { EMPTY, FOR, AGAINST }
    struct Voter {
        uint256 votesPlaced;
        uint256 lastActionNonce;
        Vote vote;
    }

    mapping(Vote => uint256) public voteCount;
    mapping(address => Voter) public voters;

    event ActionInitiated(
        bytes32 indexed callDataHash,
        uint256 indexed actionNonce,
        uint256 activatedOn,
        uint256 votingEndsOn,
        bytes callData
    );

    event ActionFinished(
        bytes32 indexed callDataHash,
        uint256 indexed actionNonce,
        uint256 activatedOn,
        uint256 votingEndedOn,
        uint256 votesFor,
        uint256 votesAgainst,
        bytes callData,
        bool executed,
        bool successfullyExecuted
    );

    event VoteChanged(
        address indexed account,
        bytes32 indexed callDataHash,
        uint256 indexed actionNonce,
        Vote vote,
        uint256 voteCountBefore,
        uint256 voteCountAfter
    );

    constructor(address crispyToken, address payable treasury) {
        finished = true;
        CRISPY_TOKEN = CrispyToken(crispyToken);
        TREASURY = Treasury(treasury);
    }

    function initiateAction(bytes calldata callData_) external {
        require(callData_.length > 0, "MVG: Cannot be empty call");
        require(finished, "MVG: Previous action not done");
        uint256 activationThreshhold_ = activationThreshhold();
        require(
            CRISPY_TOKEN.balanceOf(msg.sender) >= activationThreshhold_,
            "MVG: Below capital requirement"
        );

        _tax(activationThreshhold_);

        callData = callData_;
        uint256 activatedOn_ = block.timestamp;

        activatedOn = activatedOn_;
        finished = false;
        voteCount[Vote.FOR] = 0;
        voteCount[Vote.AGAINST] = 0;

        emit ActionInitiated(
            keccak256(callData_),
            ++actionNonce,
            activatedOn_,
            activatedOn_.add(VOTE_PERIOD),
            callData_
        );
    }

    function vote(Vote newVote) external {
        if (checkDone()) return;

        require(newVote != Vote.EMPTY, "MVG: Cannot place empty vote");
        uint256 votesAvailable = votingPowerOf(msg.sender);
        require(votesAvailable > 0, "MVG: No voting power");

        Voter storage voter = voters[msg.sender];

        uint256 oldVotesPlaced;
        Vote oldVote;

        if (voter.lastActionNonce == actionNonce) {
            oldVotesPlaced = voter.votesPlaced;
            oldVote = voter.vote;
        } else {
            voter.lastActionNonce = actionNonce;
        }

        bytes32 callDataHash = keccak256(callData);

        if (newVote != oldVote) {
            voter.vote = newVote;
            voteCount[newVote] = voteCount[newVote].add(votesAvailable);

            emit VoteChanged(
                msg.sender,
                callDataHash,
                actionNonce,
                newVote,
                uint256(0),
                votesAvailable
            );

            if (oldVote == Vote.EMPTY) {
                voter.votesPlaced = votesAvailable;
            } else {
                emit VoteChanged(
                    msg.sender,
                    callDataHash,
                    actionNonce,
                    oldVote,
                    oldVotesPlaced,
                    uint256(0)
                );
                voteCount[oldVote] = voteCount[oldVote].sub(oldVotesPlaced);
                if (votesAvailable > oldVotesPlaced) {
                    voter.votesPlaced = votesAvailable;
                }
            }
        } else {
            require(votesAvailable > oldVotesPlaced, "MVG: Can only increase vote");

            voter.votesPlaced = votesAvailable;
            uint256 newVotes = votesAvailable.sub(oldVotesPlaced);
            voteCount[newVote] = voteCount[newVote].add(newVotes);

            emit VoteChanged(
                msg.sender,
                callDataHash,
                actionNonce,
                newVote,
                oldVotesPlaced,
                votesAvailable
            );
        }
    }

    function totalAvailableVotes() public view returns(uint256) {
        uint256 treasuryReserves = CRISPY_TOKEN.balanceOf(address(TREASURY));
        return CRISPY_TOKEN.totalSupply().sub(treasuryReserves);
    }

    function votingPowerOf(address account) public view returns(uint256) {
        return voteEnd() < CRISPY_TOKEN.unlockTimes(account)
            ? CRISPY_TOKEN.balanceOf(msg.sender)
            : 0;
    }

    function voteEnd() public view returns(uint256) {
        return activatedOn.add(VOTE_PERIOD);
    }

    function checkDone() public returns(bool) {
        require(!finished, "MVG: No Action currently active");

        if (block.timestamp < voteEnd()) {
            return false;
        }

        _executeWill();
        CRISPY_TOKEN.transfer(msg.sender, finishReward);
        return true;
    }

    function activationThreshhold() public view returns(uint256) {
        return _fracMul(totalAvailableVotes(), ACTIVATION_THRESHHOLD);
    }

    function _executeWill() internal {
        uint256 votesFor = voteCount[Vote.FOR];
        uint256 votesAgainst = voteCount[Vote.AGAINST];

        uint256 votesForFraction = _fracDiv(votesFor, votesAgainst.add(votesFor));

        bool accepted = votesFor >= activationThreshhold() && votesForFraction >= ACCEPTANCE_THRESHHOLD;
        bool successfullyExecuted = false;

        if (accepted) {
            (successfullyExecuted,) = address(TREASURY).call(callData);
        }

        finished = true;
        emit ActionFinished(
            keccak256(callData),
            actionNonce,
            activatedOn,
            block.timestamp,
            votesFor,
            votesAgainst,
            callData,
            accepted,
            successfullyExecuted
        );
    }

    function _tax(uint256 amountToTax) internal {
        uint256 totalTax = _fracMul(amountToTax, ACTIVATION_TAX);
        uint256 finishReward_ = _fracMul(totalTax, FINISH_REWARD);

        CRISPY_TOKEN.transferFrom(msg.sender, address(TREASURY), totalTax.sub(finishReward_));
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
