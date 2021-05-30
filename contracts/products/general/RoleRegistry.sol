// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IRoleRegistry.sol";

contract RoleRegistry is ERC721, IRoleRegistry {
    string public version;

    bytes32 internal immutable DOMAIN_SEPARATOR;

    event RoleRegistered(
        address indexed registrant,
        bytes32 indexed roleId,
        uint256 indexed tokenId
    );

    constructor(string memory _version) ERC721("Universal role registry", "URR") {
        version = _version;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
            bytes32(0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f),
            keccak256(bytes(name())),
            keccak256(bytes(_version)),
            chainId,
            address(this)
        ));
    }

    function registerRole(bytes32 _roleId, address _account)
        external override returns(uint256)
    {
        uint256 tokenId = getTokenId(msg.sender, _roleId);
        // checks if token already exists
        _safeMint(_account, tokenId, abi.encode(_roleId));
        return tokenId;
    }

    function forceTransferRole(bytes32 _roleId, address _account)
        external override returns(uint256)
    {
        uint256 tokenId = getTokenId(msg.sender, _roleId);
        bytes memory encodedRole = abi.encode(_roleId);
        if (_exists(tokenId)) {
            _safeTransfer(ownerOf(tokenId), _account, tokenId, encodedRole);
        } else {
            _safeMint(_account, tokenId, encodedRole);
        }
        return tokenId;
    }

    function deleteRole(bytes32 _roleId) external override {
        _burn(getTokenId(msg.sender, _roleId));
    }

    function getRoleOwner(bytes32 _roleId)
        external view override returns(address)
    {
        return generalRoleOwner(msg.sender, _roleId);
    }

    function generalRoleOwner(address _registrant, bytes32 _roleId)
        public view override returns(address)
    {
        return ownerOf(getTokenId(_registrant, _roleId));
    }

    function getTokenId(address _registrant, bytes32 _roleId)
        public view override returns(uint256)
    {
        return uint256(keccak256(abi.encode(
            DOMAIN_SEPARATOR,
            IRoleRegistry.getTokenId.selector,
            _registrant,
            _roleId
        )));
    }
}
