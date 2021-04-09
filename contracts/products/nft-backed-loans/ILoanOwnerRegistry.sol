// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

interface ILoanOwnerRegistry {
    function version() external view returns(string memory);
    function getRegistryTokenId(address loan) external view returns(uint256);
    function getThisLender() external view returns(address);
}
