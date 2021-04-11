// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

interface ISimpleVault {
    event Deposit(bytes32 indexed utid, address indexed depositor);
    event Withdraw(bytes32 indexed utid, address indexed withdrawer);
    event Transfer(
        bytes32 indexed utid,
        address indexed fromController,
        address indexed toController
    );

    function withdrawToken(
        bytes32 _utid,
        address destination,
        bytes calldata data
    ) external;

    function transfer(
        bytes32 _utid,
        address _newController
    ) external;

    function getUtid(
        address _tokenContract,
        uint256 _tokenId
    ) external view returns(bytes32);

    function tokenDetail(bytes32 _utid)
        external
        view
        returns(address tokenContract, uint256 tokenId, address owner);

    function ownerOf(bytes32 _utid) external view returns(address);
}
