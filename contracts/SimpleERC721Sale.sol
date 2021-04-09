//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract SimpleERC721Sale is Ownable, IERC721Receiver {
    bool internal _initialized;

    uint256 public tokenIdToSell;
    uint256 public price;
    address public tokenAddr;
    bool public isActive;

    address private _owner; // buyer
    address public buyer;

    function init(
        address tokenAddr_,
        uint256 tokenId_,
        address buyer_,
        uint256 price_
    ) external {
        assert(!_initialized);
        _initialized = true;

        tokenAddr = tokenAddr_;
        tokenIdToSell = tokenId_;
        buyer = buyer_;
        price = price_;
        _owner = msg.sender;
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        require(operator == msg.sender, "Wrong sender address");
        require(operator == tokenAddr, "Invalid token contract");
        require(tokenId == tokenIdToSell, "Invalid tokenId");

        isActive = true;

        return IERC721Receiver.onERC721Received.selector;
    }

    function cancel() external onlyOwner {
        require(isActive, "Offer not active");
        IERC721(tokenAddr).safeTransferFrom(address(this), owner(), tokenIdToSell);
        isActive = false;
    }

    receive() external payable {
        require(isActive, "Token has not been despoited yet");
        require(msg.value >= price, "Insufficient funds");
        require(buyer == address(0) || msg.sender == buyer, "Wrong buyer");

        IERC721(tokenAddr).safeTransferFrom(address(this), msg.sender, tokenIdToSell);
        selfdestruct(payable(owner()));
    }
}
