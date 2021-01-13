// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


contract PoolSale is Ownable {
    using SafeMath for uint256;

    IERC20 public tokenBeingSold;
    address payable public treasury;
    uint256 public constant PUSH_REWARD = 0.1 ether;

    uint256 public saleStart;
    uint256 public saleEnd;

    uint256 internal _totalEthDeposited;
    uint256 public maxEther;
    uint256 public totalTokensBeingSold;
    mapping(address => uint256) public saleAllocation;

    event PoolEntered(address indexed contributor, uint256 value);

    constructor(
        uint256 saleStart_,
        uint256 saleEnd_,
        uint256 maxEther_,
        IERC20 tokenBeingSold_,
        address treasury_
    ) Ownable() {
        require(saleStart_ > block.timestamp, "Cannot set start in past");
        require(saleStart_ < saleEnd_, "Sale must end after start");

        saleStart = saleStart_;
        saleEnd = saleEnd_;
        maxEther = maxEther_;
        tokenBeingSold = tokenBeingSold_;
        treasury = payable(treasury_);
    }

    function claimTokens() external {
        require(
            totalTokensBeingSold > 0 && _totalEthDeposited > 0,
            "No push yet"
        );
        require(saleAllocation[msg.sender] > 0, "Nothing to withdraw");

        uint256 boughtTokens = getTokenAllocation(msg.sender);
        saleAllocation[msg.sender] = 0;
        tokenBeingSold.transfer(msg.sender, boughtTokens);
    }

    function enterPool() external payable {
        require(block.timestamp >= saleStart, "Sale hasn't started yet");
        require(block.timestamp <= saleEnd, "Sale has already ended");
        require(
            address(this).balance.add(msg.value) <= maxEther,
            "Pool full"
       );

       saleAllocation[msg.sender] = saleAllocation[msg.sender].add(msg.value);
    }

    function pushToTreasury() external {
        require(block.timestamp > saleEnd, "Sale hasn't ended yet");
        require(
            totalTokensBeingSold == 0 && _totalEthDeposited == 0,
            "Already pushed funds"
        );

        totalTokensBeingSold = availableTokens();
        _totalEthDeposited = address(this).balance;

        uint256 amountToBePushed = _totalEthDeposited.sub(PUSH_REWARD);
        treasury.transfer(amountToBePushed);
        msg.sender.transfer(PUSH_REWARD);
    }

    function availableTokens() public view returns(uint256) {
        return tokenBeingSold.balanceOf(address(this));
    }

    function getTokenAllocation(address account) public view returns(uint256) {
        uint256 allocation = saleAllocation[account];
        uint256 totalTokens = totalTokensBeingSold > 0
            ? totalTokensBeingSold
            : availableTokens();
        uint256 totalEth = _totalEthDeposited > 0
            ? _totalEthDeposited
            : address(this).balance;
        return allocation.mul(totalTokens).div(totalEth);
    }
}
