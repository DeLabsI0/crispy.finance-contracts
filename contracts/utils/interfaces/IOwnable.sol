// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IOwnable {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns(address);
    function transferOwnership(address newOwner) external;
}
