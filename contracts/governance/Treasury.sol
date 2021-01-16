// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "../utils/SigningContract.sol";

contract Treasury
    is Ownable,
       SigningContract,
       ERC721Holder,
       ERC1155Holder
{
    constructor(address newOwner) Ownable() {
        transferOwnership(newOwner);
    }

    receive() payable external { }

    function callDirect(
        address destination,
        uint256 value,
        bytes memory callData
    )
        external
        onlyOwner
    {
        (bool success,) = destination.call{ value: value }(callData);
        require(success);
    }

    function sign(bytes32 hash) external onlyOwner {
        _sign(hash);
    }
}
