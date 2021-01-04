// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import 'safe-qmath/contracts/SafeQMath.sol';
import './IFlashLoanRecipient.sol';

contract FlashMintERC20 is ERC20, ERC20Burnable {
    using SafeQMath for uint192;
    using SafeMath for uint256;

    uint256 public flashMintMax;
    uint192 public flashBorrowRate;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 flashMintMax_,
        uint192 flashBorrowRate_
    )
        ERC20(name_, symbol_)
    {
        _setFlashMintMax(flashMintMax_);
        _setFlashBorrowRate(flashBorrowRate_);
    }

    function startFlashLoan(uint256 borrowAmount, bytes memory callbackData)
        external
        virtual
    {
        require(
            totalSupply().add(borrowAmount) > flashMintMax,
            'FlashMintERC20: minting over max'
        );

        uint256 balanceBefore = balanceOf(address(this));
        uint256 interest = SafeQMath.intToQ(borrowAmount).qmul(flashBorrowRate).qToIntLossy();
        uint256 expectedReturnAmount = borrowAmount.add(interest);

        _mint(msg.sender, borrowAmount);
        IFlashLoanRecipient(msg.sender).onFlashLoanReady(
            expectedReturnAmount,
            callbackData
        );

        uint256 balanceAfter = balanceOf(address(this));
        burn(expectedReturnAmount);

        require(
            balanceAfter.sub(balanceBefore) == expectedReturnAmount,
            'FlashMintERC20: incorrect return'
        );
    }

    function _setFlashMintMax(uint256 flashMintMax_) internal virtual {
        flashMintMax = flashMintMax_;
    }

    function _setFlashBorrowRate(uint192 flashBorrowRate_) internal virtual {
        flashBorrowRate = flashBorrowRate_;
    }
}
