// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FaucetERC721 is ERC721 {
    uint256 public totalCreatedTokens;

    constructor(string memory name_) ERC721(name_, "TNFT") { }

    function mint(address _recipient) external {
        _safeMint(_recipient, totalCreatedTokens++);
    }
}
