// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '../governance/GovernanceToken.sol';

contract CrispyToken is GovernanceToken, Ownable {
    using SafeMath for uint256;

    uint256 public constant hardCap = 400 * 1e6 * 1e18; // 400 millio coins

    constructor()
        GovernanceToken('Crispy.finance governance & utility token', 'CRUNCH')
        Ownable()
    { }

    function mint(address recipient, uint256 amount) external onlyOwner {
        _mint(recipient, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        uint256 decreasedAllowance = allowance(account, msg.sender).sub(
            amount,
            'CRUNCH: burn exceeds allowance'
        );

        _approve(account, msg.sender, decreasedAllowance);
        _burn(account, amount);
    }

    function snapshot() external onlyOwner returns (uint256) {
        return _snapshot();
    }

    function _mint(address account, uint256 amount) internal override {
        require(
            totalSupply().add(amount) <= hardCap,
            'CRUNCH: Minting beyond hard cap'
        );
        super._mint(account, amount);
    }
}
