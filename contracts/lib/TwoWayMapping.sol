// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

library TwoWayMapping {
    struct DualMapping {
        mapping(bytes32 => bytes32) fromTo;
        mapping(bytes32 => bytes32) toFrom;
    }

    function _set(
        DualMapping storage _map,
        bytes32 _key,
        bytes32 _value
    )
        private
    {
        _map.fromTo[_key] = _value;
        _map.toFrom[_value] = _key;
    }

    function _get(DualMapping storage _map, bytes32 _key)
        private view returns (bytes32)
    {
        return _map.fromTo[_key];
    }

    function _rget(DualMapping storage _map, bytes32 _value)
        private view returns (bytes32)
    {
        return _map.toFrom[_value];
    }

    struct UintToUint {
        DualMapping inner;
    }

    function set(UintToUint storage _map, uint256 _key, uint256 _value) internal {
        _set(_map.inner, bytes32(_key), bytes32(_value));
    }

    function get(UintToUint storage _map, uint256 _key) internal view returns (uint256) {
        return uint256(_get(_map.inner, bytes32(_key)));
    }

    function rget(UintToUint storage _map, uint256 _value) internal view returns (uint256) {
        return uint256(_rget(_map.inner, bytes32(_value)));
    }
}
