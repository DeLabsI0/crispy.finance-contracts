// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/proxy/Proxy.sol";

contract TransparentConstantProxy is Proxy {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted
     * by 1
    */
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address implementation_) {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, implementation_)
        }
    }

    function implementation() public view returns(address) {
        return _implementation();
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address) {
        address implementation_;
        assembly {
            implementation_ := sload(_IMPLEMENTATION_SLOT)
        }
        return implementation_;
    }
}
