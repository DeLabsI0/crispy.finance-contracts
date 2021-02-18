// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../utils/interfaces/IOwnable.sol";

contract Ownership is ERC721 {
    uint256 public constant MASTER_OWNER_TOKEN_ID = uint256(0);

    mapping(IOwnable => address) internal _preRegisteredOwners;

    event RegisteredOwner(address indexed owned, address indexed owner);
    event OwnershipTokenized(address indexed owned);
    event OwnershipDetokenized(address indexed owned, address indexed newOwner);

    constructor() ERC721("Crispy.finance tokenized ownership", "CRTO") {
        _safeMint(msg.sender, MASTER_OWNER_TOKEN_ID);
    }

    modifier onlyOwnerOf(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "CRTO: Caller not token owner");
        _;
    }

    function registerOwnerOf(IOwnable owned) external {
        address owner = owned.owner();
        require(owner != address(this), "CRTO: Already tokenized");

        address previouslyRegisteredOwner = _preRegisteredOwners[owned];
        require(previouslyRegisteredOwner != owner, "CRTO: Already registered");

        _preRegisteredOwners[owned] = owner;
        emit RegisteredOwner(address(owned), owner);
    }

    function tokenizeOwnershipOf(IOwnable owned) external {
        require(owned.owner() == address(this), "CRTO: Self not yet owner");
        _safeMint(_preRegisteredOwners[owned], uint256(address(owned)));
        emit OwnershipTokenized(address(owned));
    }

    function detokenize(uint256 tokenId) external onlyOwnerOf(tokenId) {
        IOwnable owned = IOwnable(address(tokenId));
        owned.transferOwnership(msg.sender);
        _burn(tokenId);
    }

    function commandOwned(uint256 tokenId, bytes memory callData)
        payable
        external
        onlyOwnerOf(tokenId)
    {
        require(ownerOf(tokenId) == msg.sender, "CRTO: Caller not token owner");
        address owned = address(tokenId);

        bytes4 selector;
        assembly {
            selector := mload(add(callData, 0x20))
        }
        require(
            selector != IOwnable(owned).transferOwnership.selector,
            "CRTO: Invalid while tokenized"
        );

        (bool success, bytes memory returnData) = owned.call{ value: msg.value }(callData);
        require(success, string(returnData));
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI)
        external
        onlyOwnerOf(tokenId)
    {
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURI(string memory baseURI_) external {
        require(
            ownerOf(MASTER_OWNER_TOKEN_ID) == msg.sender,
            "CRTO: caller not master owner"
        );
        _setBaseURI(baseURI_);
    }
}
