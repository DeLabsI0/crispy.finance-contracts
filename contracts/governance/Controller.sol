// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Controller is Ownable {
    constructor() Ownable() { }

    function executeCall(
        address destination,
        bytes memory callData
    ) external payable onlyOwner returns(bytes memory) {
        (
            bool success,
            bytes memory returnData
        ) = destination.call{ value: msg.value }(callData);
        require(success, string(returnData));
        return returnData;
    }
}
