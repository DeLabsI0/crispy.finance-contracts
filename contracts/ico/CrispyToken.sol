// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/cryptography/ECDSA.sol';
import '../token/FlashMintERC20.sol';

contract CrispyToken is FlashMintERC20, Ownable {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    uint256 public constant hardCap = 400 * 1e6 * 1e18; // 400 millio coins

    bytes32 internal immutable APPROVE_SEP;
    mapping(address => uint256) internal _usedNonces;

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
        require(nonce == _usedNonces[owner], 'CRUNCH: Invalid nonce');
        require(expiry <= block.timestamp, 'CRUNCH: allowance expired');

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
            'CRUNCH: Minting beyond hard cap'
        );
        super._mint(account, amount);
    }
}
