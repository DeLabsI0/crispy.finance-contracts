// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

contract Governor {
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

        uint256 prepPhaseDuration;
        uint256 votePhaseDuration;

        uint64 proposalTax; // percent of threshhold sent to 
        uint64 proposalThreshhold;
        uint64 passRatio;

        bool canBeCalled;
        bool isEmergencyMeasure;
        uint256 bondAmount;
        address bondToken;
    }
    event GovernedParametersUpdated(
        address indexed governed,
        uint256 prepPhaseDuration,
        uint256 votePhaseDuration,
        uint256 packedFractions, // passRatio | proposalThreshhold | proposalTax
        bool canBeCalled,
        bool isEmergencyMeasure,
        uint256 bondAmount,
        address bondToken
    );

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
        uint64 selfCallTax,
        uint64 selfCallThreshhold,
        uint64 selfPassRatio,
        uint256 selfPrepDuration,
        uint256 selfVoteDuration,
        address voteWeightOracle_
    ) {
        Governed storage selfGoverned = governedParameters[address(this)];
        selfGoverned.canBeCalled = true;
        selfGoverned.prepPhaseDuration = selfPrepDuration;
        selfGoverned.votePhaseDuration = selfVoteDuration;
        selfGoverned.proposalTax = selfCallTax;
        selfGoverned.proposalThreshhold = selfCallThreshhold;
        selfGoverned.passRatio = selfPassRatio;

        _updatedGoverned(address(this));
        _setVoteWeightOracle(voteWeightOracle_);
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Governor: Not authorized");
        _;
    }

    function updateGovernedParams(
        address governed,
        uint256 prepPhaseDuration,
        uint256 votePhaseDuration,
        uint256 packedFractions, // passRatio | proposalThreshhold | proposalTax
        bool canBeCalled,
        bool isEmergencyMeasure,
        uint256 bondAmount,
        address bondToken,
        bytes memory callData
    )
        external
        onlySelf
    {
        uint64 proposalTax = uint64(packedFractions);
        uint64 proposalThreshhold = uint64(packedFractions >> 64);
        uint64 passRatio = uint64(packedFractions >> 128);

        governedParameters[governed] = Governed({
            prepPhaseDuration: prepPhaseDuration,
            votePhaseDuration: votePhaseDuration,
            proposalTax: proposalTax,
            proposalThreshhold: proposalThreshhold,
            passRatio: passRatio,
            canBeCalled: canBeCalled,
            isEmergencyMeasure: isEmergencyMeasure,
            bondAmount: bondAmount,
            bondToken: bondToken
        });

        if (callData.length > 0) {
            (bool success,) = governed.call(callData);
            require(success);
        }
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

    function _updatedGoverned(address governed) internal {
        Governed storage params = governedParameters[governed];
        uint256 packedFractions = uint256(params.proposalTax)
            | (uint256(params.proposalThreshhold) << 64)
            | (uint256(params.passRatio) << 128);

        emit GovernedParametersUpdated(
            governed,
            params.prepPhaseDuration,
            params.votePhaseDuration,
            packedFractions,
            params.canBeCalled,
            params.isEmergencyMeasure,
            params.bondAmount,
            params.bondToken
        );
    }

    function _setVoteWeightOracle(address voteWeightOracle_) internal {
        voteWeightOracle = voteWeightOracle_;
    }
}
