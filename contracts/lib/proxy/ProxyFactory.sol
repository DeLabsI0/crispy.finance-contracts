// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "./TransparentConstantProxy.sol";

library ProxyFactory {
    function createProxyFrom(address implementation) internal returns(address) {
        return address(new TransparentConstantProxy(implementation));
    }
}
