// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "ez-staker-contracts/contracts/IHexTransferable.sol";
import "ez-staker-contracts/contracts/IHex.sol";

interface IEzStaker is IHexTransferable {
    function hexToken() external view returns(IHex);
}
