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
    string public currentBaseURI;

    TwoWayMapping.UintToUint internal _tokenIdToStakeIndex;

    event ExtendStake(uint256 indexed tokenId);

    constructor(uint256 _fee, IHex _hexToken)
        ERC721("Crispy.finance tokenized hex stakes", "CHXS")
        FeeTaker(_fee)
    {
        hexToken = _hexToken;
    }

    function createStakesFor(
        address _recipient,
        uint256[] memory _stakeAmounts,
        uint256[] memory _stakeDays,
        uint256 _maxFee,
        uint256 _upfrontTotal
    )
        external
    {
        uint256 stakeAmountsLength = _stakeAmounts.length;
        require(stakeAmountsLength == _stakeDays.length, "CHXS: Input length mismatch");
        _pullFundsAtFee(_upfrontTotal, _maxFee);
        uint256 realTotal;
        uint256 totalIssuedTokens_ = totalIssuedTokens;
        for (uint256 i; i < stakeAmountsLength; i++) {
            uint256 stakeAmount = _stakeAmounts[i];
            realTotal += stakeAmount;
            unchecked {
                uint256 newTokenId = totalIssuedTokens_ + i;
                _issueNewTokenFor(_recipient, stakeAmount, _stakeDays[i], newTokenId);
            }
        }
        unchecked {
            totalIssuedTokens += stakeAmountsLength;
        }
        uint256 stakeCost = _addFeeForTotal(realTotal, hexToken);
        require(_upfrontTotal >= stakeCost, "CHXS: Insufficient funds");
        unchecked {
            uint256 refundAmount = _upfrontTotal - stakeCost;
            if (refundAmount > 0) hexToken.safeTransfer(msg.sender, refundAmount);
        }
    }

    function createStakeFor(
        address _recipient,
        uint256 _totalAmount,
        uint256 _stakeDays,
        uint256 _maxFee
    )
        external
    {
        _pullFundsAtFee(_totalAmount, _maxFee);
        uint256 stakeAmount = _takeFeeFrom(_totalAmount, hexToken);
        uint256 newTokenId = totalIssuedTokens++;
        _issueNewTokenFor(_recipient, stakeAmount, _stakeDays, newTokenId);
    }

    function setBaseURI(string calldata _newBaseURI) external onlyOwner {
        currentBaseURI = _newBaseURI;
    }

    function unstakeManyTo(address _recipient, uint256[] memory _tokenIds)
        external
    {
        uint256 balanceBefore = hexToken.balanceOf(address(this));
        for (uint256 i; i < _tokenIds.length; i++) {
            _redeemToken(_tokenIds[i]);
        }
        uint256 balanceAfter = hexToken.balanceOf(address(this));
        hexToken.safeTransfer(_recipient, balanceAfter - balanceBefore);
    }

    function unstakeTo(address _recipient, uint256 _tokenId) external {
        uint256 balanceBefore = hexToken.balanceOf(address(this));
        _redeemToken(_tokenId);
        uint256 balanceAfter = hexToken.balanceOf(address(this));
        hexToken.safeTransfer(_recipient, balanceAfter - balanceBefore);
    }

    function extendStakeLength(
        uint256 _tokenId,
        uint256 _newStakeDays,
        uint256 _maxFee,
        uint256 _addedAmount
    )
        external
    {
        uint256 balanceBefore = hexToken.balanceOf(address(this));
        _pullFundsAtFee(_addedAmount, _maxFee);
        _closeStake(_tokenId);
        uint256 balanceAfter = hexToken.balanceOf(address(this));
        uint256 newStakeAmount = _takeFeeFrom(balanceAfter - balanceBefore, hexToken);
        _openStake(newStakeAmount, _newStakeDays, _tokenId);
        emit ExtendStake(_tokenId);
    }

    function getStakeIndex(uint256 _tokenId) public view returns (uint256) {
        return _tokenIdToStakeIndex.get(_tokenId);
    }

    function getTokenId(uint256 _stakeIndex) public view returns (uint256) {
        return _tokenIdToStakeIndex.rget(_stakeIndex);
    }

    function _pullFundsAtFee(uint256 _total, uint256 _maxFee) internal {
        _checkFeeAtMost(_maxFee);
        if (_total > 0) {
            hexToken.safeTransferFrom(msg.sender, address(this), _total);
        }
    }

    function _issueNewTokenFor(
        address _recipient,
        uint256 _stakeAmount,
        uint256 _stakeDays,
        uint256 _newTokenId
    )
        internal
    {
        _openStake(_stakeAmount, _stakeDays, _newTokenId);
        _safeMint(_recipient, _newTokenId);
    }

    function _openStake(
        uint256 _stakeAmount,
        uint256 _stakeDays,
        uint256 _tokenId
    )
        internal
    {
        uint256 newStakeIndex = hexToken.stakeCount(address(this));
        _tokenIdToStakeIndex.set(_tokenId, newStakeIndex);
        hexToken.stakeStart(_stakeAmount, _stakeDays);
    }

    function _redeemToken(uint256 _tokenId) internal {
        _closeStake(_tokenId);
        _burn(_tokenId);
    }

    function _closeStake(uint256 _tokenId) internal {
        _authenticateToken(_tokenId);
        (uint256 stakeIndex, uint40 stakeId) = _getStakeFromToken(_tokenId);
        unchecked {
            uint256 lastStakeIndex = hexToken.stakeCount(address(this)) - 1;
            if (stakeIndex != lastStakeIndex) {
                uint256 topTokenId = getTokenId(lastStakeIndex);
                _tokenIdToStakeIndex.set(topTokenId, stakeIndex);
            }
            hexToken.stakeEnd(stakeIndex, stakeId);
        }
    }

    function _authenticateToken(uint256 _tokenId) internal view {
        require(_isApprovedOrOwner(msg.sender, _tokenId), "CHXS: Caller not approved");
    }

    function _getStakeFromToken(uint256 _tokenId)
        internal view returns (uint256 stakeIndex, uint40 stakeId)
    {
        stakeIndex = getStakeIndex(_tokenId);
        (stakeId,,,,,,) = hexToken.stakeLists(address(this), stakeIndex);
    }

    function _baseURI() internal view override returns (string memory) {
        return currentBaseURI;
    }
}
