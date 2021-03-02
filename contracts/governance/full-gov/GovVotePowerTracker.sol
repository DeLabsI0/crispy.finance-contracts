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
        address delegate = _delegates[voter];
        address actingVoter = delegate == address(0) ? voter : delegate;
        _votingPower[actingVoter] = _votingPower[actingVoter].add(votes);
    }

    function _removeVotes(address voter, uint256 votes) internal {
        _baseVotingPower[voter] = _baseVotingPower[voter].sub(votes);
        address delegate = _delegates[voter];
        address actingVoter = delegate == address(0) ? voter : delegate;
        _votingPower[actingVoter] = _votingPower[actingVoter].sub(votes);
    }
}
