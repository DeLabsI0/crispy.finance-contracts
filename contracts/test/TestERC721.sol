// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    constructor(string memory name_) ERC721(name_, "TNFT") { }

    function mint(address recipient, uint256 tokenId) external {
        _safeMint(recipient, tokenId);
    }
}
