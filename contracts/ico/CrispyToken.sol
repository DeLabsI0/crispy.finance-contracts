// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '../governance/GovernanceToken.sol';

contract CrispyToken is GovernanceToken, Ownable {
    using SafeMath for uint256;

    uint256 public constant hardCap = 125 * 1e6 * 1e18;

    constructor()
        GovernanceToken('Crispy.finance governance & utility token', 'CRUNCH')
        Ownable()
    { }

    function _mint(address account, uint256 amount) internal override {
        require(
            totalSupply().add(amount) <= hardCap,
            'Minting beyond hard cap'
        );
        super._mint(account, amount);
    }
}
