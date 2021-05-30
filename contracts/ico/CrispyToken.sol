// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ITransferHookReceiver.sol";

contract CrispyToken is ERC20, ERC20Burnable, Ownable {
    ITransferHookReceiver public hookReceiver;

    event TransferHookReceiverSet(address indexed newReceiver);

    constructor(address _hookReceiver)
        ERC20("Crispy.finance governance & utility token", "CRSPY")
        ERC20Burnable()
        Ownable()
    {
        _setHookReceiver(_hookReceiver);
    }

    function mint(address recipient, uint256 amount) external onlyOwner {
        _mint(recipient, amount);
    }

    function setHookReceiver(address _newHookReceiver) external onlyOwner {
        _setHookReceiver(_newHookReceiver);
    }

    function _setHookReceiver(address _newHookReceiver) internal {
        hookReceiver = ITransferHookReceiver(_newHookReceiver);
        emit TransferHookReceiverSet(_newHookReceiver);
    }

//(ERC20, ERC20Burnable)
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {

    }
}
