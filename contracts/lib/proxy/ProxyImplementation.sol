// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

abstract contract ProxyImplementation {
    /*
     * whether the instance cannot be initialized
     *
     * slot key is the keccak256 hash
     * 'crispy.proxy.implementation.notInitializable' - 1
    */
    bytes32 private constant _NOT_INITIALIZABLE_SLOT =
        0x28be7a417183ac2bd473365e3d1dc8d849a912eb249cce0f4f62c68d9951bb25;


    /*
     * whether the instance has been initialized
     *
     * slot key is the keccak256 hash
     * 'crispy.proxy.implementation.initialized' - 1
    */
    bytes32 private constant _INITIALIZED_SLOT  =
        0xf869a1a53b5fa38e5b6d217801c6385f0946a5bc29f98b6bc2b0d34e57644a30;

    constructor() {
        assembly {
            sstore(_NOT_INITIALIZABLE_SLOT, true)
        }
    }

    modifier onlyInitialized() {
        require(_initialized(), "ProxyImpl: not initialized");
        _;
    }

    modifier initializer() {
        require(!_initialized(), "ProxyImpl: already initialized");
        bool initializable;
        assembly {
            initializable := not(sload(_NOT_INITIALIZABLE_SLOT))
        }
        require(initializable, "ProxyImpl: not initializable");
        _;
        assembly {
            sstore(_INITIALIZED_SLOT, true)
        }
    }

    function _initialized() internal view returns(bool) {
        bool initialized;
        assembly {
            initialized := sload(_INITIALIZED_SLOT)
        }
        return initialized;
    }
}
