// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../general/IRoleRegistry.sol";
import "../../general/ISimpleVault.sol";

contract AuthorizationModule {
    using SafeERC20 for IERC20;

    // keccak256('crispy-finance.loan.lender')
    bytes32 public constant LENDER_ROLE =
        0x7da4deb1cca08695be671b2c22403c152700c24264576fcbca70ff13e1a20351;
    // keccak256('crispy-finance.loan.debtor')
    bytes32 public constant DEBTOR_ROLE =
        0x20cdbd9e32b90544fc90f15609623e3d66e3101194596dfdfcf1155a695083d7;

    IERC20 public token;
    IRoleRegistry public roleRegistry;
    ISimpleVault public vault;
    bytes32 public collatUtid;

    uint256 public accountedPayments; // amount that has already been repayed

    function _init(
        IERC20 _token,
        IRoleRegistry _roleRegistry,
        ISimpleVault _vault,
        bytes32 _collatUtid
    ) internal {
        require(
            _vault.ownerOf(_collatUtid) == address(this),
            "AuthModule: Must own collateral"
        );
        token = _token;
        roleRegistry = _roleRegistry;
        vault = _vault;
        collatUtid = _collatUtid;
        _roleRegistry.registerRole(LENDER_ROLE, msg.sender);
        _roleRegistry.registerRole(DEBTOR_ROLE, msg.sender);
    }

    modifier onlyRole(bytes32 _role) {
        require(
            roleRegistry.getRoleOwner(_role) == msg.sender,
            "AuthModule: Missing role"
        );
        _;
    }

    function withdrawPayment(uint256 _amount) external onlyRole(LENDER_ROLE) {
        accountedPayments -= _amount;
        token.safeTransfer(msg.sender, _amount);
    }

    function _releaseCollateral(address _recipient) internal {
        vault.transfer(collatUtid, _recipient);
    }
}
