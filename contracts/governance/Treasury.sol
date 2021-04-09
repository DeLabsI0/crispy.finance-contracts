// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Treasury is Ownable, ERC721Holder, ERC1155Holder {
    constructor() Ownable() { }

    receive() payable external { }

    // transfers native token such as ETH, xDAI, Matic or BNB
    function transferNative(address recipient, uint256 amount) external onlyOwner {
        payable(recipient).transfer(amount);
    }

    function transferERC20(IERC20 token, address recipient, uint256 amount)
        external
        onlyOwner
    {
        SafeERC20.safeTransfer(token, recipient, amount);
    }

    function transferERC721(
        IERC721 token,
        address recipient,
        uint256 tokenId,
        bytes memory data
    )
        external
        onlyOwner
    {
        token.safeTransferFrom(address(this), recipient, tokenId, data);
    }

    function transferERC1155(
        IERC1155 token,
        address recipient,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    )
        external
        onlyOwner
    {
        token.safeTransferFrom(address(this), recipient, tokenId, amount, data);
    }
}
