// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IOrderListener.sol";

contract ActionHouse is IERC721Receiver, IOrderListener {
    uint256 internal constant SCALE = 1e18;
    address public immutable market;

    // Open Bid Ascending Auction
    struct OBAAuction {
        address owner;
        IERC20 paymentToken;
        uint256 startTime;
        uint256 totalDuration;
        uint256 highestBidOrderId;
        uint256 minimumIncrease;
        uint256 highestBid;
        bool hasWhitelist;
        mapping(address => bool) isWhitelisted;
    }

    mapping(IERC721 => mapping(uint256 => OBAAuction)) public auctions;

    constructor(address _market) {
        market = _market;
    }

    function onERC721Received(
        address _operator,
        address,
        uint256 _tokenId,
        bytes calldata _data
    ) external override returns(bytes4) {
        (
            IERC20 paymentToken,
            uint256 startingBid,
            uint256 minimumIncrease,
            uint256 auctionDuration,
            bool hasWhitelist
        ) = abi.decode(_data, (IERC20, uint256, uint256, uint256, bool));
        _createAuction(
            _operator,
            IERC721(msg.sender),
            _tokenId,
            paymentToken,
            startingBid,
            minimumIncrease,
            auctionDuration,
            hasWhitelist
        );
        return IERC721Receiver.onERC721Received.selector;
    }

    function receiveOrder(
        uint256 _orderId,
        address _creator,
        bool _isSellOrder,
        address _permittedFiller,
        IERC721 _tokenContract,
        uint256 _tokenId,
        IERC20 _paymentToken,
        uint256 _paymentAmount,
        uint256 _allowedInverseFee
    ) external override {
        require(msg.sender == market, "AuctionHouse: not market order");
        OBAAuction storage auction = auctions[_tokenContract][_tokenId];
        require(_paymentToken == auction.paymentToken, "AuctionHouse: wrong token");
        require(
            !auction.hasWhitelist || auction.isWhitelisted[_creator],
            "AuctionHouse: not whitelisted"
        );
        uint256 minimumBid = auction.startTime == 0
            ? auction.highestBid
            : auction.highestBid * auction.minimumIncrease / SCALE;
        require(_pay)

    }

    function _createAuction(
        address _owner,
        IERC721 _tokenContract,
        uint256 _tokenId,
        IERC20 _paymentToken,
        uint256 _startingBid,
        uint256 _minimumIncrease,
        uint256 _auctionDuration,
        bool _hasWhitelist
    ) internal {
        OBAAuction storage auction = auctions[_tokenContract][_tokenId];
        auction.owner = _owner;
        auction.paymentToken = _paymentToken;
        auction.totalDuration = _auctionDuration;
        auction.minimumIncrease = _minimumIncrease;
        auction.highestBid = _startingBid; // starting bid stored here to save gas
        auction.hasWhitelist = _hasWhitelist;
    }
}
