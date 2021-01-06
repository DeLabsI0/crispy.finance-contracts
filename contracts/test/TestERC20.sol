// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
    constructor(string memory name_) ERC20(name_, 'TST') {
        _mint(msg.sender, 100000 ether);
    }

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }
}
