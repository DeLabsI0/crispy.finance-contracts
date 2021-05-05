// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "./IRoleRegistry.sol";

contract RoleManager {
    IRoleRegistry public roleRegistry;

    constructor(IRoleRegistry _roleRegistry) {
        roleRegistry = _roleRegistry;
    }

    modifier onlyRole(bytes32 _role) {
        require(
            roleRegistry.getRoleOwner(_role) == msg.sender,
            "RoleManager: Missing role"
        );
        _;
    }
}
