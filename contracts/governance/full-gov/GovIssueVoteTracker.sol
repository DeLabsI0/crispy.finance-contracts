// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "./GovVotePowerTracker.sol";

contract GovIssueVoteTracker is GovVotePowerTracker {
    mapping(bytes32 => uint256) internal _totalVotesFor;
    mapping(bytes32 => uint256) internal _totalVotesAgainst;
    mapping(bytes32 => mapping(address => uint256)) internal _votersVotesFor;
    mapping(bytes32 => mapping(address => uint256)) internal _votersVotesAgainst;

    function _voteFor(address voter, bytes32 issue) internal virtual {
        uint256 prevVotesAgainst = _votersVotesAgainst[issue][voter];
        if (prevVotesAgainst > 0) {
            _totalVotesAgainst[issue] -= prevVotesAgainst;
            _votersVotesAgainst[issue][voter] = 0;
        }

        uint256 prevVotesFor = _votersVotesFor[issue][voter];
        uint256 votingPower = _votingPower[voter];
        if (votingPower > prevVotesFor) {
            _votersVotesFor[issue][voter] = votingPower;
            _totalVotesFor[issue] = votingPower - prevVotesFor;
        }
    }

    function _voteAgainst(address voter, bytes32 issue) internal virtual {
        uint256 prevVotesFor = _votersVotesFor[issue][voter];
        if (prevVotesFor > 0) {
            _totalVotesFor[issue] -= prevVotesFor;
            _votersVotesFor[issue][voter] = 0;
        }

        uint256 prevVotesAgainst = _votersVotesAgainst[issue][voter];
        uint256 votingPower = _votingPower[voter];
        if (votingPower > prevVotesAgainst) {
            _votersVotesAgainst[issue][voter] = votingPower;
            _totalVotesAgainst[issue] += votingPower - prevVotesAgainst;
        }
    }
}
