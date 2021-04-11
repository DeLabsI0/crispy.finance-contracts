// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./ISimpleVault.sol";

contract SimpleVault is ISimpleVault, IERC721Receiver {
    string public constant name = "Universal ERC721 vault";
    string public version;
    bytes32 internal immutable DOMAIN_SEPARATOR;

    struct Token {
        address tokenContract;
        uint256 tokenId;
        address owner;
    }
    mapping(bytes32 => Token) public override tokenDetail;

    constructor(string memory _version) {
        version = _version;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
            bytes32(0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f),
            keccak256(bytes(name)),
            keccak256(bytes(_version)),
            chainId,
            address(this)
        ));
    }

    function onERC721Received(
        address _operator,
        address,
        uint256 _tokenId,
        bytes calldata
    )
        external
        override
        returns (bytes4)
    {
        bytes32 utid = registerToken(msg.sender, _tokenId);
        tokenDetail[utid].owner = _operator;
        emit Deposit(utid, _operator);
        return IERC721Receiver.onERC721Received.selector;
    }

    function transfer(bytes32 _utid, address _newController) external override {
        require(ownerOf(_utid) == msg.sender, "SimpleVault: not owner");
        tokenDetail[_utid].owner = _newController;
        emit Transfer(_utid, msg.sender, _newController);
    }

    function withdrawToken(bytes32 _utid) external override {
        require(ownerOf(_utid) == msg.sender, "SimpleVault: not owner");
        tokenDetail[_utid].owner = address(0);
        emit Withdraw(_utid, msg.sender);
    }

    function registerToken(address _tokenContract, uint256 _tokenId)
        public
        returns(bytes32 utid)
    {
        utid = getUtid(_tokenContract, _tokenId);
        tokenDetail[utid].tokenContract = _tokenContract;
        tokenDetail[utid].tokenId = _tokenId;
    }

    function ownerOf(bytes32 _utid) public view override returns(address) {
        return tokenDetail[_utid].owner;
    }

    function getUtid(address _tokenContract, uint256 _tokenId)
        public
        view
        override
        returns(bytes32)
    {
        return keccak256(abi.encodePacked(
            DOMAIN_SEPARATOR,
            bytes4(0x3b3097fc), // getUtid selector 
            _tokenContract,
            _tokenId
        ));
    }
}
