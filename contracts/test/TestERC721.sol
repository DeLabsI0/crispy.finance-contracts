// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721, Ownable {
    constructor(string memory name_) ERC721(name_, "TNFT") Ownable() { }

    function mint(address recipient, uint256 tokenId) external onlyOwner {
        _safeMint(recipient, tokenId);
    }
}
