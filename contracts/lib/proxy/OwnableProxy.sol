// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract OwnableProxy is ERC165Storage, Initializable {
    address internal _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(owner() == msg.sender, "OwnableProxy: not owner");
        _;
    }

    function init(address _initialOwner) external initializer {
        _owner = _initialOwner;
        emit OwnershipTransferred(address(0), _initialOwner);
        _registerInterface(0x7f5828d0); // register ERC173 interface
    }

    function owner() public view virtual returns(address) {
        return _owner;
    }

    function transferOwnership(address _newOwner) public virtual onlyOwner {
        emit OwnershipTransferred(_owner, _newOwner);
        _owner = _newOwner;
    }
}
