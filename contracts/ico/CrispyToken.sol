// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '../token/FlashMintERC20.sol';

contract CrispyToken is FlashMintERC20, Ownable {
    using SafeMath for uint256;

    uint256 public constant hardCap = 400 * 1e6 * 1e18; // 400 millio coins

    bytes32 internal immutable APPROVE_SEP;
    mapping(bytes32 => bool) internal _usedHashes;

    constructor(uint256 flashMintMax_, uint192 flashBorrowRate_)
        FlashMintERC20(
            'Crispy.finance governance & utility token',
            'CRUNCH',
            flashMintMax_,
            flashBorrowRate_
        )
        Ownable()
    {
        bytes32 domainSeparator = keccak256(abi.encode(name(), address(this)));
        APPROVE_SEP = keccak256(abi.encode(domainSeparator, approve.selector));
    }

    function setFlashMintMax(uint192 flashMintMax_) external onlyOwner {
        _setFlashMintMax(flashMintMax_);
    }

    function setFlashBorrowRate(uint192 flashBorrowRate_) external onlyOwner {
        _setFlashBorrowRate(flashBorrowRate_);
    }

    function mint(address recipient, uint256 amount) external onlyOwner {
        _mint(recipient, amount);
    }

    function _mint(address account, uint256 amount) internal override {
        require(
            totalSupply().add(amount) <= hardCap,
            'CRUNCH: Minting beyond hard cap'
        );
        super._mint(account, amount);
    }
}
