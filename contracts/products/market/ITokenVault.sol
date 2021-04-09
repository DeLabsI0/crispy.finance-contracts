// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ITokenVault is IERC721Receiver {
    event TokenDeposited(
        bytes32 indexed utid,
        address indexed controller,
        address indexed depositor
    );
    event TokenControlTransferred(
        bytes32 indexed utid,
        address indexed fromController,
        address indexed toController
    );
    event TokenWithdrawn(
        bytes32 indexed utid,
        address indexed controller,
        address indexed dest
    );

    function withdrawToken(
        bytes32 utid,
        address destination,
        bytes calldata data
    ) external;

    function transferControl(
        bytes32 utid,
        address newController,
        address operator,
        bytes calldata data
    ) external;

    function getUniversalTokenId(
        address token,
        uint256 tokenId
    ) external view returns(bytes32);

    function tokens(bytes32 utid) external view returns(
        address token,
        uint256 tokenId,
        address controller
    );
}
