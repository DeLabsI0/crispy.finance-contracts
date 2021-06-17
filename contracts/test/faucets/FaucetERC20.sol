// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FaucetERC20 is ERC20 {
    constructor(string memory name_) ERC20(name_, "TST") { }

    function mint(address _recipient, uint256 _amount) external {
        _mint(_recipient, _amount);
    }
}
