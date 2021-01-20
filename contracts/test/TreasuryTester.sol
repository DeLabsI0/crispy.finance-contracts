// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

contract TreasuryTester {
    bytes32 public constant key = keccak256("password");
    uint256 public constant requiredAmount = uint256(keccak256("seed xD #1")) % (2 ether);

    function access(bytes32 key_) external payable {
        require(key == key_);
        require(msg.value == requiredAmount);
    }
}
