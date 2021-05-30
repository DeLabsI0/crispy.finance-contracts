// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Arrays.sol";

library ValueSnapshots {
    using Arrays for uint256[];

    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }

    function getValueAt(Snapshots storage snapshots, uint256 snapshotId)
        internal view returns (bool, uint256)
    {
        require(snapshotId > 0, "ValueSnapshots: id is 0");

        uint256 index = snapshots.ids.findUpperBound(snapshotId);

        if (index == snapshots.ids.length) {
            return (false, 0);
        } else {
            return (true, snapshots.values[index]);
        }
    }

    function update(
        Snapshots storage snapshots,
        uint256 currentValue,
        uint256 currentId
    ) internal {
        if (getLastId(snapshots) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function getLastId(Snapshots storage snapshots)
        internal view returns (uint256)
    {
        uint256 snapIdLength = snapshots.ids.length;
        if (snapIdLength == 0) {
            return 0;
        } else {
            return snapshots.ids[snapIdLength - 1];
        }
    }
}
