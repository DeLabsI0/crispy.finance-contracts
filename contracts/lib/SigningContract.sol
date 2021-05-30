// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

/*
    follows the ERC1271 standard (05.01.2021)
*/
abstract contract SigningContract {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 constant internal ERC1271_MAGIC = 0x1626ba7e;

    mapping(bytes32 => bool) internal _signedHashes;

    function hashSigned(bytes32 hash) public view virtual returns (bool) {
        return _signedHashes[hash];
    }

    function isValidSignature(bytes32 hash, bytes memory)
        public
        view
        returns (bytes4)
    {
        return hashSigned(hash) ? ERC1271_MAGIC : bytes4(0);
    }

    function _sign(bytes32 hash) internal virtual {
        _signedHashes[hash] = true;
    }
}
