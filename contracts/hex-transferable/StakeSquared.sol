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

    uint256 internal _rewardsEndTime;
    uint256 internal _rewardsToDistribute;

    struct UserData {
        uint256[] depositedTokens;
        uint256 stakedShares;
        uint192 rewardsAccumulator;
    }

    mapping(address => UserData) internal _userData;

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

    //function 

    function increaseEmissionRate(uint256 increasedEmissionRate)
        external
        onlyOwner
    {
        require(
            increasedEmissionRate > emissionRate,
            "Staker^2: can only increase rate"
        );

        assert(false); // add update accumulators and reward

        emissionRate = increasedEmissionRate;
    }

    function getMetaStakedTokenCount(address account)
        public
        view
        returns(uint256)
    {
        return _userData[account].depositedTokens.length;
    }

    function getMetaStakedToken(
        address account,
        uint256 tokenIndex
    )
        public
        view
        returns(uint256)
    {
        return _userData[account].depositedTokens[tokenIndex];
    }

    function getStakedShares(uint256 tokenId) public view returns(uint256) {
        uint256 stakeIndex = ezStaker.getStakeIndex(tokenId);
        (,,uint72 stakeShares,,,,) = _hexToken.stakeLists(
            address(ezStaker),
            stakeIndex
        );
        return uint256(stakeShares);
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    )
        external
        override
        returns (bytes4)
    {
        require(msg.sender == address(ezStaker), "Staker^2: Invalid ERC721 NFT");

        _userData[operator].depositedTokens.push(tokenId);

        uint256 stakedShares = getStakedShares(tokenId);
        _totalStakedShares = _totalStakedShares.add(stakedShares);

        return this.onERC721Received.selector;
    }
}
