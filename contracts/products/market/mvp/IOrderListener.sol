// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOrderListener {
    function receiveOrder(
        address _creator,
        bool _isSellOrder,
        address _permittedFiller,
        IERC721 _tokenContract,
        uint256 _tokenId,
        IERC20 _paymentToken,
        uint256 _paymentAmount,
        uint256 _allowedInverseFee
    ) external;
}
