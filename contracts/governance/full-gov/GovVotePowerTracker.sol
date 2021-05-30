// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

contract GovVotePowerTracker {
    mapping(address => uint256) internal _votingPower;
    mapping(address => uint256) internal _baseVotingPower;
    mapping(address => address) internal _delegates;

    function _addVotes(address voter, uint256 votes) internal {
        _baseVotingPower[voter] += votes;
        address actingVoter = _getActingVoter(voter, _delegates[voter]);
        _votingPower[actingVoter] += votes;
    }

    function _removeVotes(address voter, uint256 votes) internal {
        _baseVotingPower[voter] -= votes;
        address actingVoter = _getActingVoter(voter, _delegates[voter]);
        _votingPower[actingVoter] -= votes;
    }

    function _setDelegate(address voter, address newDelegate) internal returns(bool) {
        address prevActingVoter = _getActingVoter(voter, _delegates[voter]);
        address newActingVoter = _getActingVoter(voter, newDelegate);
        if (prevActingVoter == newActingVoter) {
            return false;
        }
        uint256 basePow = _baseVotingPower[voter];
        _votingPower[prevActingVoter] = basePow;
        _votingPower[newActingVoter] = basePow;
        return true;
    }

    function _getActingVoter(address voter, address delegate)
        internal
        pure
        returns(address)
    {
        return delegate == address(0) ? voter : delegate;
    }
}
