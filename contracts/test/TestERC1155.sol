// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';

contract TestERC1155 is ERC1155  {
    constructor(string memory uri_) ERC1155(uri_) { }

    function mint(address recipient, uint256 id, uint256 amount) external {
        _mint(recipient, id, amount, '');
    }
}
