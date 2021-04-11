/*
// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILoanOwnerRegistry.sol";

contract Loan is ILoan, Initializable {
    using SafeERC20 for IERC20;

    // core properties
    ILoanOwnerRegistry public override registry;


    bytes32 public override tokenUtid;

    function init(
        IERC20 _token,
        uint256 _principal
    )
        external override initializer
    {
        registry = ILoanOwnerRegistry(msg.sender);
        token = _token;
        principal = _principal;
    }

    function onFunding() external onlyWhen(Status.COLLATERLIZED) {
        require(msg.sender == address(registry), "Loan: Not registry");
        token.transfer(owner(), principal);
        debt = principal;
        lastPayment = block.timestamp;
        _setStatus(Status.CLOSED);
    }

}*/
