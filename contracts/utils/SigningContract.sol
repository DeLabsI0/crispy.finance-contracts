// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

/*
follows the ERC1271 standard (05.01.2021)
*/
abstract contract SigningContract {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 constant internal MAGICVALUE = 0x1626ba7e;

    mapping(bytes32 => bool) internal _signedHashes;

    function hashSigned(bytes32 hash) public view virtual returns (bool) {
        return _signedHashes[hash];
    }

    function isValidSignature(bytes32 hash, bytes memory)
        public
        view
        returns (bytes4)
    {
        return hashSigned(hash) ? MAGICVALUE : bytes4(0);
    }

    function _sign(bytes32 hash) internal virtual {
        _signedHashes[hash] = true;
    }
}
