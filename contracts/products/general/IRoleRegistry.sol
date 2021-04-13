// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IRoleRegistry is IERC721 {
    function registerRole(bytes32 _roleId, address _account)
        external returns(uint256);
    function forceTransferRole(bytes32 _roleId, address _account)
        external returns(uint256);
    function deleteRole(bytes32 _roleId) external;
    function getRoleOwner(bytes32 _roleId) external view returns(address);
    function generalRoleOwner(address _registrant, bytes32 _roleId)
        external view returns(address);
    function getTokenId(address _registrant, bytes32 _roleId)
        external view returns(uint256);
}
