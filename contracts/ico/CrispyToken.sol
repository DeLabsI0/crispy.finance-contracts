// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CrispyToken is ERC20, ERC20Capped, ERC20Burnable, Ownable {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    uint256 public constant HARD_CAP = 400 * 1e6 * 1e18; // 400 million coins

    // EIP712
    string public constant version = "1";
    bytes32 public immutable DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    mapping(address => uint256) public nonces;
    mapping(address => uint256) public unlockTimes;

    event BalanceLocked(address indexed account, uint256 unlockTime);

    constructor()
        ERC20("Crispy.finance governance & utility token", "CRSPY")
        ERC20Capped(HARD_CAP)
        ERC20Burnable()
        Ownable()
    {
        uint256 chainId_;
        assembly {
            chainId_ := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            //keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), 
            0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
            keccak256(bytes(name())),
            keccak256(bytes(version)),
            chainId_,
            address(this)
        ));
    }

    function lockBalance(uint256 unlockTime) external {
        require(unlockTime > unlockTimes[msg.sender], "CRSPY: Invalid unlock time");
        require(unlockTime > block.timestamp, "CRSPY: Unlock time passed");

        unlockTimes[msg.sender] = unlockTime;
        emit BalanceLocked(msg.sender, unlockTime);
    }

    function mint(address recipient, uint256 amount) external onlyOwner {
        _mint(recipient, amount);
    }

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        bytes32 digest = getPermitDigest(holder, spender, nonce, expiry, allowed);
        require(holder == ecrecover(digest, v, r, s), "CRSPY: invalid permit");
        require(expiry == 0 || block.timestamp <= expiry, "CRSPY: permit expired");
        require(nonce == nonces[holder]++, "CRSPY: invalid nonce");

        _approve(holder, spender, allowed ? type(uint256).max : 0);
    }

    function getPermitDigest(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed
    )
        public
        pure
        returns(bytes32)
    {
        bytes32 permitDigest = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            holder,
            spender,
            nonce,
            expiry,
            allowed
        ));
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            permitDigest
        ));
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Capped)
    {
        super._beforeTokenTransfer(from, to, amount);
        require(block.timestamp >= unlockTimes[from], "CRSPY: Balance locked");
    }
}
