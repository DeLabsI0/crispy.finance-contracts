// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "../token/FlashMintERC20.sol";

contract CrispyToken is FlashMintERC20, Ownable {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    uint256 public constant hardCap = 400 * 1e6 * 1e18; // 400 million coins

    bytes32 internal immutable APPROVE_SEP;
    mapping(address => uint256) internal _usedNonces;
    mapping(address => uint256) internal _lockTimes;

    event BalanceLocked(address indexed account, uint256 unlockTime);

    constructor(uint256 flashMintMax_, uint192 flashBorrowRate_)
        FlashMintERC20(
            "Crispy.finance governance & utility token",
            "CRUNCH",
            flashMintMax_,
            flashBorrowRate_
        )
        Ownable()
    {
        bytes32 domainSeparator = keccak256(abi.encode(name(), address(this)));
        APPROVE_SEP = keccak256(abi.encode(domainSeparator, approve.selector));
    }

    function lockBalance(uint256 unlockTime) external {
        require(unlockTime > _lockTimes[msg.sender], "CRUNCH: Invalid unlock time");
        require(unlockTime > block.timestamp, "CRUNCH: Unlock time passed");

        _lockTimes[msg.sender] = unlockTime;
        emit BalanceLocked(msg.sender, unlockTime);
    }

    function approveWithSignature(
        uint256 nonce,
        uint256 expiry,
        address owner,
        address spender,
        uint256 amount,
        bytes memory signature
    )
        external
    {
        require(nonce == _usedNonces[owner], "CRUNCH: Invalid nonce");
        require(expiry <= block.timestamp, "CRUNCH: allowance expired");

        bytes32 approveHash = getApproveHash(
            nonce,
            expiry,
            owner,
            spender,
            amount
        );

        require(
            owner == approveHash.toEthSignedMessageHash().recover(signature),
            'CRUNCH: Invalid signature'
        );

        _approve(owner, spender, amount);
        _usedNonces[owner]++;
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

    function getUnlockTime(address account) public view returns (uint256) {
        return _lockTimes[account];
    }

    function getUsedNonces(address account) public view returns (uint256) {
        return _usedNonces[account];
    }

    function getApproveHash(
        uint256 nonce,
        uint256 expiry,
        address owner,
        address spender,
        uint256 amount
    )
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(
            APPROVE_SEP, nonce, expiry, owner, spender, amount
        ));
    }

    function _mint(address account, uint256 amount) internal override {
        require(
            totalSupply().add(amount) <= hardCap,
            "CRUNCH: Minting beyond hard cap"
        );
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal override
    {
        super._beforeTokenTransfer(from, to, amount);
        require(block.timestamp >= getUnlockTime(from), "CRUNCH: Balance locked");
    }
}
