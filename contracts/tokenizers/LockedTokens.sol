// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../lib/TransferHelper.sol";

contract LockedTokens is ERC721, Ownable {
    struct TokenizedLock {
        address token;
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => uint256) internal _tokenNonce;
    mapping(uint256 => TokenizedLock) internal _tokenizedLocks;

    constructor()
        ERC721("Crispy.finance tokenized timelocked tokens", "CR3T")
        Ownable()
    { }

    function lockTokens(address token, uint256 amount, uint256 unlockTime)
        external
    {
        _lockTokens(token, amount, unlockTime, msg.sender);
    }

    function lockTokensFor(
        address token,
        uint256 amount,
        uint256 unlockTime,
        address recipient
    )
        external
    {
        _lockTokens(token, amount, unlockTime, recipient);
    }

    function spreadLockTokens(
        address token,
        uint256[] memory amounts,
        uint256[] memory unlockTimes,
        address[] memory recipients
    )
        external
    {
        require(
            amounts.length == unlockTimes.length &&
            unlockTimes.length == recipients.length,
            "CR3T: Input lengths do not match"
        );
        uint256 curNonce = _tokenNonce[token];
        uint256 totalToDeposit = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalToDeposit = SafeMath.add(totalToDeposit, amounts[i]);
            uint256 tokenId = uint256(keccak256(
                abi.encode(token, curNonce + i)
            ));
            _recordLock(
                tokenId,
                token,
                amounts[i],
                unlockTimes[i],
                recipients[i]
            );
        }
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            totalToDeposit,
            "CR3T: Deposit failed"
        );
        _tokenNonce[token] = curNonce + amounts.length;
    }

    function unlockTokens(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "CR3T: Must be owner to redeem");
        TokenizedLock memory tokenizedLock = _tokenizedLocks[tokenId];
        require(
            tokenizedLock.unlockTime <= block.timestamp,
            "CR3T: Tokens not unlocked yet"
        );
        TransferHelper.safeTransfer(
            tokenizedLock.token,
            msg.sender,
            tokenizedLock.amount,
            "CR3T: Redeem failed"
        );
        _burn(tokenId);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _setBaseURI(baseURI_);
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        require(ownerOf(tokenId) == msg.sender, "CR3T: Must be owner to redeem");
        _setTokenURI(tokenId, _tokenURI);
    }

    function getLockInfo(uint256 tokenId)
        public
        view
        returns(
            address token,
            uint256 amount,
            uint256 unlockTime
        )
    {
        token = _tokenizedLocks[tokenId].token;
        amount = _tokenizedLocks[tokenId].amount;
        unlockTime = _tokenizedLocks[tokenId].unlockTime;
    }

    function getNonce(address token) public view returns(uint256) {
        return _tokenNonce[token];
    }

    function genTokenId(address token, uint256 nonce)
        public
        view
        returns(uint256)
    {
        return uint256(keccak256(abi.encode(token, nonce)));
    }

    function _lockTokens(
        address token,
        uint256 amount,
        uint256 unlockTime,
        address recipient
    )
        internal
    {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount,
            "CR3T: Deposit failed"
        );
        uint256 tokenId = genTokenId(token, _tokenNonce[token]++);
        _recordLock(tokenId, token, amount, unlockTime, recipient);
    }

    function _recordLock(
        uint256 tokenId,
        address token,
        uint256 amount,
        uint256 unlockTime,
        address recipient
    )
        internal
    {
        require(unlockTime > block.timestamp, "CR3T: unlock time in the past");
        TokenizedLock memory tokenizedLock;
        tokenizedLock.token = token;
        tokenizedLock.amount = amount;
        tokenizedLock.unlockTime = unlockTime;
        _tokenizedLocks[tokenId] = tokenizedLock;
        _safeMint(recipient, tokenId);
    }
}
