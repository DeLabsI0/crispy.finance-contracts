// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/SigningContract.sol";

contract Controller is Ownable, SigningContract {
    constructor() Ownable() { }

    function executeCall(
        address destination,
        bytes memory callData
    ) external payable onlyOwner returns(bytes memory) {
        (
            bool success,
            bytes memory returnData
        ) = destination.call{ value: msg.value }(callData);
        require(success);
        return returnData;
    }

    function sign(bytes32 hash) external onlyOwner {
        _sign(hash);
    }
}
