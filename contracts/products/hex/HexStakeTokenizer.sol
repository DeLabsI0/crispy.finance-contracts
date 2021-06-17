// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../lib/FeeTaker.sol";
import "../../lib/interfaces/IHex.sol";
import "../../lib/TwoWayMapping.sol";

contract HexStakeTokenizer is ERC721, FeeTaker {
    using SafeERC20 for IHex;
    using TwoWayMapping for TwoWayMapping.UintToUint;

    IHex public immutable hexToken;
    uint256 public totalIssuedTokens;
    uint256 public totalSupply;
    string public currentBaseURI;

    /*
       TODO: batch stake creation
    */

    // stores stakeId to make sure stakes cannot be confused
    mapping(uint256 => uint256) internal _stakeIdOfToken;
    TwoWayMapping.UintToUint internal _tokenIdToStakeIndex;

    constructor(uint256 _fee, IHex _hexToken)
        ERC721("Crispy.finance tokenized hex stakes", "CHXS")
        FeeTaker(_fee)
    {
        hexToken = _hexToken;
    }

    function createStakes(
        uint256[] memory _totalAmounts,
        uint256[] memory _stakeDays,
        uint256 _maxFee,
        uint256 _total
    )
        external
    {
        createStakesFor(msg.sender, _totalAmounts, _stakeDays, _maxFee, _total);
    }

    function createStakesFor(
        address _recipient,
        uint256[] memory _totalAmounts,
        uint256[] memory _stakeDays,
        uint256 _maxFee,
        uint256 _total
    )
        public
    {
        _checkFeeAtMost(_maxFee);
        require(_totalAmounts.length == _stakeDays.length, "CHXS: Input length mismatch");
        hexToken.safeTransferFrom(msg.sender, address(this), _total);
        uint256 afterFeeTotal = _takeFee(hexToken, _total);
        uint256 realTotal;
        for (uint256 i; i < _totalAmounts.length; i++) {
            uint256 totalAmount = _totalAmounts[i];
            realTotal += totalAmount;
            _stakeFor(_recipient, totalAmount, _stakeDays[i]);
        }
        require(afterFeeTotal >= realTotal, "CHXS: Insufficient funds");
        unchecked {
            uint256 refundAmount = afterFeeTotal - realTotal;
            if (refundAmount > 0) hexToken.safeTransfer(msg.sender, refundAmount);
        }
    }

    function createStake(
        uint256 _totalAmount,
        uint256 _stakeDays,
        uint256 _maxFee
    )
        external
    {
        createStakeFor(msg.sender, _totalAmount, _stakeDays, _maxFee);
    }

    function createStakeFor(
        address _recipient,
        uint256 _totalAmount,
        uint256 _stakeDays,
        uint256 _maxFee
    )
        public
    {
        _checkFeeAtMost(_maxFee);
        hexToken.safeTransferFrom(msg.sender, address(this), _totalAmount);
        uint256 stakeAmount = _takeFee(hexToken, _totalAmount);
        _stakeFor(_recipient, stakeAmount, _stakeDays);
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        currentBaseURI = _newBaseURI;
    }

    function directStakeTo(address _recipient, uint256 _stakeAmount, uint256 _stakeDays)
        external onlyOwner
    {
        hexToken.safeTransferFrom(msg.sender, address(this), _stakeAmount);
        _stakeFor(_recipient, _stakeAmount, _stakeDays);
    }

    function unstakeMany(uint256[] memory _tokenIds) external {
        unstakeManyTo(msg.sender, _tokenIds);
    }

    function unstakeManyTo(address _recipient, uint256[] memory _tokenIds)
        public
    {
        for (uint256 i; i < _tokenIds.length; i++) {
            unstakeTo(_recipient, _tokenIds[i]);
        }
    }

    function unstake(uint256 _tokenId) external {
        unstakeTo(msg.sender, _tokenId);
    }

    function unstakeTo(address _recipient, uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "CHXS: Not token owner");
        uint256 stakeIndex = _tokenIdToStakeIndex.get(_tokenId);
        uint256 stakeId = _verifyTokenStake(_tokenId, stakeIndex);
        _unstakeTo(_recipient, _tokenId, stakeIndex, stakeId);
    }

    /* should only be used if there is a bug in the sc and `unstakeTo` no longer
       works */
    function manualUnstakeTo(
        address _recipient,
        uint256 _tokenId,
        uint256 _stakeIndex
    )
        external
    {
        require(ownerOf(_tokenId) == msg.sender, "CHXS: Not token owner");
        uint256 stakeId = _verifyTokenStake(_tokenId, _stakeIndex);
        _unstakeTo(_recipient, _tokenId, _stakeIndex, stakeId);
    }

    function getStakeIndex(uint256 _tokenId) public view returns (uint256) {
        return _tokenIdToStakeIndex.get(_tokenId);
    }

    function getTokenId(uint256 _stakeIndex) public view returns (uint256) {
        return _tokenIdToStakeIndex.rget(_stakeIndex);
    }

    function getTokenStakeId(uint256 _tokenId) public view returns (uint256) {
        return _stakeIdOfToken[_tokenId];
    }

    function _stakeFor(
        address _stakeRecipient,
        uint256 _stakeAmount,
        uint256 _stakeDays
    )
        internal
    {
        uint256 newTokenId = totalIssuedTokens++;
        uint256 newStakeIndex = totalSupply;
        _tokenIdToStakeIndex.set(newTokenId, newStakeIndex);
        hexToken.stakeStart(_stakeAmount, _stakeDays);
        _stakeIdOfToken[newTokenId] = _getStakeIdOf(newStakeIndex);
        _safeMint(_stakeRecipient, newTokenId);
    }

    function _unstakeTo(
        address _recipient,
        uint256 _tokenId,
        uint256 _stakeIndex,
        uint256 _stakeId
    )
        internal
    {
        _endStakeTo(_recipient, _stakeIndex, _stakeId);
        _burn(_tokenId);

        // if it wasn't the last stake in the list something got rearanged
        uint256 totalSupply_ = totalSupply;
        if (_stakeIndex != totalSupply_) {
            uint256 topTokenId = _tokenIdToStakeIndex.rget(totalSupply_);
            _tokenIdToStakeIndex.set(topTokenId, _stakeIndex);
        }
    }

    function _endStakeTo(
        address _recipient,
        uint256 _stakeIndex,
        uint256 _stakeId
    )
        internal
    {
        uint256 balanceBefore = hexToken.balanceOf(address(this));
        hexToken.stakeEnd(_stakeIndex, uint40(_stakeId));
        unchecked {
            uint256 unstakeAmount = hexToken.balanceOf(address(this)) - balanceBefore;
            hexToken.safeTransfer(_recipient, unstakeAmount);
        }
    }

    function _verifyTokenStake(uint256 _tokenId, uint256 _stakeIndex)
        internal view returns (uint256 stakeId)
    {
        stakeId = _getStakeIdOf(_stakeIndex);
        require(_stakeIdOfToken[_tokenId] == stakeId, "CHXS: Invalid stake index");
    }

    function _getStakeIdOf(uint256 _stakeIndex) internal view returns (uint256) {
        (uint40 stakeId,,,,,,) = hexToken.stakeLists(address(this), _stakeIndex);
        return uint256(stakeId);
    }

    function _baseURI() internal view override returns (string memory) {
        return currentBaseURI;
    }

    function _mint(address _to, uint256 _tokenId) internal override {
        totalSupply++;
        super._mint(_to, _tokenId);
    }

    function _burn(uint256 _tokenId) internal override {
        totalSupply--;
        super._burn(_tokenId);
    }
}
