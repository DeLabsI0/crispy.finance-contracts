// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ITokenVault.sol";
import "./IDepositController.sol";

contract TokenVault is ITokenVault, ReentrancyGuard {
    string public name;
    string public version;

    struct Token {
        address token;
        uint256 tokenId;
        address controller;
    }
    mapping(bytes32 => Token) public override tokens;

    bytes32 internal immutable DOMAIN_SEPARATOR;

    constructor(string memory _name, string memory _version) ReentrancyGuard() {
        name = _name;
        version = _version;

        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR = keccak256(abi.encode(
            // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
            bytes32(0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f),
            keccak256(bytes(_name)),
            keccak256(bytes(_version)),
            chainId,
            address(this)
        ));
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata depositData
    )
        external
        override
        nonReentrant
        returns (bytes4)
    {
        (
            address controller,
            bytes memory data
        ) = abi.decode(depositData, (address, bytes));
        require(controller != address(0), "Market: Invalid token controller");
        bytes32 utid = getUniversalTokenId(msg.sender, tokenId);
        require(tokens[utid].controller == address(0), "Market: Token already deposited");

        tokens[utid] = Token({
            token: msg.sender,
            tokenId: tokenId,
            controller: controller
        });
        IDepositController(controller).onTokenDeposit(operator, utid, data);
        emit TokenDeposited(utid, controller, operator);
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdrawToken(
        bytes32 utid,
        address destination,
        bytes calldata data
    )
        external
        override
        nonReentrant
    {
        Token storage token = tokens[utid];
        require(token.controller == msg.sender, "Market: Not controller");

        IERC721(token.token).safeTransferFrom(
            address(this),
            destination,
            token.tokenId,
            data
        );
        token.controller = address(0);
        emit TokenWithdrawn(utid, msg.sender, destination);
    }

    function transferControl(
        bytes32 utid,
        address newController,
        address operator,
        bytes calldata data
    )
        external
        override
        nonReentrant
    {
        Token storage token = tokens[utid];
        require(token.controller == msg.sender, "Market: Not controller");

        token.controller = newController;
        IDepositController(newController).onTokenDeposit(operator, utid, data);
        emit TokenControlTransferred(utid, msg.sender, newController);
    }

    function getUniversalTokenId(address token, uint256 tokenId)
        public
        view
        override
        returns(bytes32)
    {
        return keccak256(abi.encode(DOMAIN_SEPARATOR, token, tokenId));
    }
}
