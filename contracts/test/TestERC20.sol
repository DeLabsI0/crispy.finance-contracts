// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
    constructor(string memory name_) ERC20(name_, 'TST') {
        _mint(msg.sender, 100000 ether);
    }

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }
}
