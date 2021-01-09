// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "ez-staker-contracts/contracts/IHex.sol";
import "safe-qmath/contracts/SafeQMath.sol";
import "./IEzStaker.sol";

/*
    Allows users who have staked hex via crispy to stake their stakes to earn
    CRUNCH tokens
*/
contract StakeSquared is IERC721Receiver, Ownable {
    using SafeQMath for uint192;
    using SafeMath for uint256;

    IERC20 public rewardToken;
    IEzStaker public ezStaker;
    uint256 public emissionRate;

    IHex internal _hexToken;
    uint192 internal _rewardsAccumulator;
    uint256 internal _totalStakedShares;

    mapping(uint256 => address) internal _depositors;

    constructor(
        IERC20 rewardToken_,
        IEzStaker ezStaker_,
        uint256 emissionRate_
    )
        Ownable()
    {
        rewardToken = rewardToken_;
        ezStaker = ezStaker_;
        emissionRate = emissionRate_;
        _hexToken = ezStaker_.hexToken();
    }

    function increaseEmissionRate(uint256 increasedEmissionRate)
        external
        onlyOwner
    {
        require(
            increasedEmissionRate > emissionRate
            "Staker^2: can only increase rate"
        );

        assert(false); // add update accumulators and reward

        emissionRate = increasedEmissionRate;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    )
        public
        override
        returns (bytes4)
    {
        require(msg.sender == address(ezStaker), "Staker^2: Invalid ERC721 NFT");

        _depositors[tokenId] = operator;
        uint256 stakeIndex = ezStaker.getStakeIndex(tokenId);
        (,,uint72 stakeShares,,,,) = _hexToken.stakeLists(
            address(ezStaker),
            stakeIndex
        );

        _totalStakedShares = _totalStakedShares.add(uint256(stakeShares));

        return this.onERC721Received.selector;
    }
}
