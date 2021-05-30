// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "./GovIssueVoteTracker.sol";

contract GovIssueTracker is GovIssueVoteTracker {
    mapping(bytes32 => bool) internal _issueIsActive;

    function _voteFor(address voter, bytes32 issue) internal override {
        require(_issueIsActive[issue], "Gov: Issue inactive");
        super._voteFor(voter, issue);
    }

    function _voteAgainst(address voter, bytes32 issue) internal override {
        require(_issueIsActive[issue], "Gov: Issue inactive");
        super._voteAgainst(voter, issue);
    }
}
