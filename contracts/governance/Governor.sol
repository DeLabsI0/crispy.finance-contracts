// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "safe-qmath/contracts/SafeQMath.sol";

contract Governor {
    using SafeQMath for uint192;

    /**
     * @dev stores data about addresses that are governed by this governance
     * contract
     *
     * @param canBeCalled whether a proposal to send a transaction to a certain
     * address can be made at all
     * @param proposalTax fractional number indicating the percentage that is
     * sent to the treasury upon creating a proposal
     * @param proposalThreshhold fractional number indicating the percentage of
     * the total voting power (vote weight units) required to create a proposal
     * for this address
     * @param passRatio fractional number indicating the fraction of votes that
     * have to be in favor of a proposal in order for it to pass
     * @param isEmergencyMeasure whether emergency proposals can be initiated.
     * These proposals are executed instantly with a vote following on whether
     * to reverse the proposal and slash the bond
     * @param bondAmount token amount required to initiate an emergency measure
     * @param bondToken address of ERC20 token used for bond
     */
    struct Governed {
        bool canBeCalled;

        uint256 prepPhaseDuration;
        uint256 votePhaseDuration;

        uint192 proposalTax; // percent of threshhold sent to 
        uint192 proposalThreshhold;
        uint192 passRatio;

        bool isEmergencyMeasure;
        uint256 bondAmount;
        address bondToken;
    }

    struct Action {
        address target;
        bytes payload;
    }

    struct Proposal {
        bool completed;
        uint256 votingStarts;
        uint256 votingEnds;
        Action[] actions;
    }

    mapping(address => Governed) public governedParameters;
    address public voteWeightOracle;

    mapping(bytes32 => Proposal) internal _proposals;

    constructor(
        uint192 selfCallTax,
        uint192 selfCallThreshhold,
        uint192 selfPassRatio,
        uint256 selfPrepDuration,
        uint256 selfVoteDuration,
        address voteWeightOracle_
    ) {
        governedParameters[address(this)] = Governed({
            canBeCalled: true,
            prepPhaseDuration: selfPrepDuration,
            votePhaseDuration: selfVoteDuration,
            proposalTax: selfCallTax,
            proposalThreshhold: selfCallThreshhold,
            passRatio: selfPassRatio,
            isEmergencyMeasure: false,
            bondAmount: 0,
            bondToken: address(0)
        });

        _setVoteWeightOracle(voteWeightOracle_);
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Governor: Not authorized");
        _;
    }

    function setVoteWeightOracle(address voteWeightOracle_) external onlySelf {
        _setVoteWeightOracle(voteWeightOracle_);
    }

    function getAction(bytes32 proposalId, uint256 actionIndex)
        public
        view
        returns (address target, bytes memory payload)
    {
        target = _proposals[proposalId].actions[actionIndex].target;
        payload = _proposals[proposalId].actions[actionIndex].payload;
    }

    function getActionCount(bytes32 proposalId) public view returns (uint256) {
        return _proposals[proposalId].actions.length;
    }

    function isComplete(bytes32 proposalId) public view returns (bool) {
        return _proposals[proposalId].completed;
    }

    function _setVoteWeightOracle(address voteWeightOracle_) internal {
        voteWeightOracle = voteWeightOracle_;
    }
}
