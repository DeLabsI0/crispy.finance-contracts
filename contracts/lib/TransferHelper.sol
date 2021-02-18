// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

library TransferHelper {
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value,
        string memory errorMsg
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            errorMsg
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value,
        string memory errorMsg
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            errorMsg
        );
    }
}
