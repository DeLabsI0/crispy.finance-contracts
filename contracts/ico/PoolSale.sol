// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


contract PoolSale is Ownable {
    using SafeMath for uint256;

    IERC20 public tokenBeingSold;

    uint256 public saleStart;
    uint256 public saleEnd;

    uint256 public maxEther;
    uint256 public unclaimedAllocation;
    mapping(address => uint256) public saleAllocation;

    event PoolEntered(address indexed contributor, uint256 value);

    constructor(
        uint256 saleStart_,
        uint256 saleEnd_,
        uint256 maxEther_,
        IERC20 tokenBeingSold_
    ) Ownable() {
        require(saleStart_ > block.timestamp, 'Cannot set start in past');
        require(saleStart_ < saleEnd_, 'Sale must end after start');

        saleStart = saleStart_;
        saleEnd = saleEnd_;
        maxEther = maxEther_;
        tokenBeingSold = tokenBeingSold_;
    }

    function claimTokens() external {
        require(block.timestamp > saleEnd, "Sale hasn't ended yet");

        uint256 allocation = saleAllocation[msg.sender];
        require(allocation > 0, 'Nothing to withdraw');

        uint256 boughtTokens = tokenBeingSold.balanceOf(address(this)).mul(allocation).div(address(this).balance);

        saleAllocation[msg.sender] = 0;
        unclaimedAllocation =  unclaimedAllocation.sub(allocation);
        tokenBeingSold.transfer(msg.sender, boughtTokens);
    }

    function enterPool() external payable {
        require(block.timestamp >= saleStart, "Sale hasn't started yet");
        require(block.timestamp <= saleEnd, 'Sale has already ended');
        require(
            address(this).balance.add(msg.value) <= maxEther,
            'Pool full'
       );

       saleAllocation[msg.sender] = saleAllocation[msg.sender].add(msg.value);
       unclaimedAllocation = unclaimedAllocation.add(msg.value);
    }

}
