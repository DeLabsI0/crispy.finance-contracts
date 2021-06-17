// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "./IFullERC20.sol";

// Hex interface

/*
// actual structs as a reference
struct StakeStore {
    uint40 stakeId;
    uint72 stakedHearts;
    uint72 stakeShares;
    uint16 lockedDay;
    uint16 stakedDays;
    uint16 unlockedDay;
    bool isAutoStake;
}

struct GlobalsStore {
    // 1
    uint72 lockedHeartsTotal;
    uint72 nextStakeSharesTotal;
    uint40 shareRate;
    uint72 stakePenaltyTotal;
    // 2
    uint16 dailyDataCount;
    uint72 stakeSharesTotal;
    uint40 latestStakeId;
    uint128 claimStats;
}
*/

interface IHex is IFullERC20 {
    event StakeStart(
        uint256 data0,
        address indexed stakerAddr,
        uint40 indexed stakeId
    );

    event StakeGoodAccounting(
        uint256 data0,
        uint256 data1,
        address indexed stakerAddr,
        uint40 indexed stakeId,
        address indexed senderAddr
    );

    event StakeEnd(
        uint256 data0,
        uint256 data1,
        address indexed stakerAddr,
        uint40 indexed stakeId
    );

    function stakeStart(uint256 newStakedHearts, uint256 newStakedDays) external;
    function stakeEnd(uint256 stakeIndex, uint40 stakeIdParam) external;
    function stakeGoodAccounting(
        address stakerAddr,
        uint256 stakeIndex,
        uint40 stakeIdParam
    ) external;

    // mapping(address => StakeStore[]) public stakeLists;
    function stakeLists(address owner, uint256 index)
        external
        view
        returns (
            uint40 stakeId,
            uint72 stakedHearts,
            uint72 stakeShares,
            uint16 lockedDay,
            uint16 stakedDays,
            uint16 unlockedDay,
            bool isAutoStake
        );

    // GlobalsStore public globals;
    function globals() external view returns (
        uint72 lockedHeartsTotal,
        uint72 nextStakeSharesTotal,
        uint40 shareRate,
        uint72 stakePenaltyTotal,
        uint16 dailyDataCount,
        uint72 stakeSharesTotal,
        uint40 latestStakeId,
        uint128 claimStats
    );
    function stakeCount(address stakerAddr) external view returns (uint256);
    function currentDay() external view returns (uint256);
    function dailyData(uint256 day) external view returns (
        uint72 dayPayoutTotal,
        uint72 dayStakeSharesTotal,
        uint56 dayUnclaimedSatoshisTotal
    );
} 
