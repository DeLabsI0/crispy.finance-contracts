// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../ico/CrispyToken.sol";
import "../Treasury.sol";

/*
  MVG (Minimum Viable Governance)

  minimal implementation of a governance mechanism to govern the community
  treasury
*/
contract MVG {
    using SafeMath for uint256;

    CrispyToken public constant CRISPY_TOKEN = CrispyToken(/* CRUNCH address */ address(0));
    Treasury public constant TREASURY = Treasury(/* Treasury address */ address(0));

    uint256 public constant VOTE_PERIOD = 7 days;

    uint256 public constant ONE = 100000;
    uint256 public constant ACTION_ACTIVATION_THRESHHOLD = 1000; // 1%
    uint256 public constant ACTION_ACTIVATION_TAX = 800; // 0.8%
    uint256 public constant ACTION_ACCEPTANCE_THRESHHOLD = 60000; // 60%

    enum Vote { EMPTY, FOR, AGAINST }

    struct Voter {
        Vote vote;
        uint256 votesPlaced;
    }
    event Voted(
        bytes32 indexed actionId,
        address indexed voter,
        uint256 voteCount,
        Vote vote
    );
    event ActionVotedOn(
        bytes32 indexed actionId,
        uint256 fromAgainst,
        uint256 fromFor,
        uint256 toAgainst,
        uint256 toFor
    );

    struct Action {
        bytes callData;
        uint256 activated;
        bool finished;
        mapping(Vote => uint256) votes;
        mapping(address => Voter) voters;
    }
    event ActionCreated(bytes32 indexed actionId);
    event ActionActivated(bytes32 indexed actionId, uint256 activatedTimestamp);
    event ActionTerminated(bytes32 indexed actionId, bool executed);

    mapping(bytes32 => Action) internal _actions;
    mapping(bytes32 => uint256) internal _nonces;

    constructor() { }

    modifier watchVotes(bytes32 actionId) {
        uint256 fromAgainst = _actions[actionId].votes[Vote.AGAINST];
        uint256 fromFor = _actions[actionId].votes[Vote.FOR];
        _;
        uint256 toAgainst = _actions[actionId].votes[Vote.AGAINST];
        uint256 toFor = _actions[actionId].votes[Vote.FOR];
        emit ActionVotedOn(actionId, fromAgainst, fromFor, toAgainst, toFor);
    }

    modifier onlyWithExistingAction(bytes32 actionId) {
        require(_actions[actionId].callData.length > 0, "MVG: Action not found");
        _;
    }

    function createAction(bytes memory callData) external returns(bytes32) {
        require(callData.length > 0, "MVG: Cannot be empty call");
        bytes32 callId = keccak256(callData);
        uint256 newNonce = _nonces[callId]++;
        bytes32 actionId = keccak256(abi.encodePacked(callId, newNonce));

        _actions[actionId].callData = callData;
        emit ActionCreated(actionId);

        return actionId;
    }

    function activateAction(bytes32 actionId)
        external
        onlyWithExistingAction(actionId)
    {
        require(!getActionActivated(actionId), "MVG: Action already activated");
        uint256 activationThreshhold =
            _fracMul(totalAvailableVotes(), ACTION_ACTIVATION_THRESHHOLD);
        require(
            CRISPY_TOKEN.balanceOf(msg.sender) >= activationThreshhold,
            "MVG: Below capital requirement"
        );

        CRISPY_TOKEN.transferFrom(
            msg.sender,
            address(TREASURY),
            _fracMul(activationThreshhold, ACTION_ACTIVATION_TAX)
        );

        uint256 actionActivated = block.timestamp;
        _actions[actionId].activated = actionActivated;
        emit ActionActivated(actionId, actionActivated);
    }

    function voteOn(bytes32 actionId, Vote vote)
        external
        onlyWithExistingAction(actionId)
    {
        require(getActionActivated(actionId), "MVG: Action not activated yet");
        uint256 votingEnd = getVotingEnd(actionId);
        require(votingEnd > block.timestamp, "MVG: Voting has ended");
        require(
            votingEnd <= CRISPY_TOKEN.getUnlockTime(msg.sender),
            "MVG: Must lock tokens to vote"
        );

        _vote(actionId, CRISPY_TOKEN.balanceOf(msg.sender), vote);
    }

    function terminateAction(bytes32 actionId)
        external
        onlyWithExistingAction(actionId)
    {
        require(
            getVotingEnd(actionId) <= block.timestamp,
            "MVG: Voting hasn't ended yet"
        );

        Action storage action = _actions[actionId];

        uint256 votesFor = action.votes[Vote.FOR];
        uint256 votesAgainst = action.votes[Vote.AGAINST];
        uint256 voteForFraction = _fracDiv(
            votesFor,
            votesFor.add(votesAgainst)
        );

        action.finished = true;
        // if (voteForFraction >)
    }

    function getActionActivated(bytes32 actionId) public view returns(bool) {
        return _actions[actionId].activated > 0;
    }

    function getVotingEnd(bytes32 actionId) public view returns(uint256) {
        return _actions[actionId].activated.add(VOTE_PERIOD);
    }

    function totalAvailableVotes() public view returns(uint256) {
        uint256 treasuryReserves = CRISPY_TOKEN.balanceOf(address(TREASURY));
        return CRISPY_TOKEN.totalSupply().sub(treasuryReserves);
    }

    function _fracMul(uint256 intX, uint256 fracY) internal pure returns(uint256) {
        return intX.mul(fracY).div(ONE);
    }

    function _fracDiv(uint256 intX, uint256 intY) internal pure returns(uint256) {
        return intX.mul(ONE).div(intY);
    }

    function _oppositeVote(Vote vote) internal pure returns(Vote) {
        if (vote == Vote.AGAINST) return Vote.FOR;
        if (vote == Vote.FOR) return Vote.AGAINST;
        return Vote.EMPTY;
    }

    function _vote(
        bytes32 actionId,
        uint256 voteCount,
        Vote newVote
    )
        internal
        watchVotes(actionId)
    {
        require(newVote != Vote.EMPTY, "MVG: Cannot place empty vote");
        emit Voted(actionId, msg.sender, voteCount, newVote);

        Action storage action = _actions[actionId];
        Voter storage voter = action.voters[msg.sender];
        Vote oldVote = voter.vote;


        if (oldVote != newVote) {
            voter.vote = newVote;
            action.votes[newVote] = action.votes[newVote].add(voteCount);

            if (oldVote == Vote.EMPTY) {
                voter.votesPlaced = voteCount;
            } else {
                action.votes[oldVote] = action.votes[oldVote].sub(voter.votesPlaced);
                if (voteCount > voter.votesPlaced) {
                    voter.votesPlaced = voteCount;
                }
            }
        } else {
            require(voteCount > voter.votesPlaced, "MVG: Can only increase vote");

            voter.votesPlaced = voteCount;
            uint256 newVotes = voteCount.sub(voter.votesPlaced);
            action.votes[newVote] = action.votes[newVote].add(newVotes);
        }
    }
}
