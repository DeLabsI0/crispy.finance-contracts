// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract GovVotePowerTracker {
    using SafeMath for uint256;

    mapping(address => uint256) internal _votingPower;
    mapping(address => uint256) internal _baseVotingPower;
    mapping(address => address) internal _delegates;

    function _addVotes(address voter, uint256 votes) internal {
        _baseVotingPower[voter] = _baseVotingPower[voter].add(votes);
        address actingVoter = _getActingVoter(voter, _delegates[voter]);
        _votingPower[actingVoter] = _votingPower[actingVoter].add(votes);
    }

    function _removeVotes(address voter, uint256 votes) internal {
        _baseVotingPower[voter] = _baseVotingPower[voter].sub(votes);
        address actingVoter = _getActingVoter(voter, _delegates[voter]);
        _votingPower[actingVoter] = _votingPower[actingVoter].sub(votes);
    }

    function _setDelegate(address voter, address newDelegate) internal returns(bool) {
        address prevActingVoter = _getActingVoter(voter, _delegates[voter]);
        address newActingVoter = _getActingVoter(voter, newDelegate);
        if (prevActingVoter == newActingVoter) {
            return false;
        }
        uint256 basePow = _baseVotingPower[voter];
        _votingPower[prevActingVoter] = _votingPower[prevActingVoter].sub(basePow);
        _votingPower[newActingVoter] = _votingPower[newActingVoter].add(basePow);
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
