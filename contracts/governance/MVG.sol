// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../ico/CrispyToken.sol";
import "./Treasury.sol";

/*
  MVG (Minimum Viable Governance)

  minimal implementation of a governance mechanism to govern the community
  treasury
*/
contract MVG {
    IERC20 public constant CRISPY_TOKEN = CrispyToken(/* CRUNCH address */ address(0));
    Treasury public constant TREASURY = Treasury(/* Treasury address */ address(0));

    uint256 public constant VOTE_PERIOD = 7 days;
    uint192 public constant ACTION_ACTIVATION_THRESHHOLD = 0x028f5c28f5c28f5c; // 1%
    uint192 public constant ACTION_ACTIVATION_TAX        = 0x0083126e978d4fdf; // 0.2%
    uint192 public constant ACTION_ACCEPTANCE_THRESHHOLD = 0x999999999999999a; // 60%

    struct Action {
        bytes callData;
        uint256 actionActivated;
        bool actionTerminated;
    }
    event ActionCreated(bytes32 indexed callDataHash, uint256 actionIndex);
    event ActionActivated(
        bytes32 indexed callDataHash,
        uint256 actionIndex,
        uint256 activatedTimestamp
    );
    event ActionTerminated(
        bytes32 indexed callDataHash,
        uint256 actionIndex,
        bool executed
    );

    mapping(bytes32 => Action) internal _actions;
    mapping(bytes32 => uint256) internal _nonces;

    constructor() { }

    function createAction(bytes memory callData) external returns(uint256) {
        bytes32 callDataHash = keccak256(callData);
        uint256 actionIndex = _actions[callDataHash].length;

        _actions[callDataHash].push(Action({ callData: callData }));
    }
}
