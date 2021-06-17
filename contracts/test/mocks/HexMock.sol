// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HexMock is ERC20, Ownable {
    struct StakeStore {
        uint40 stakeId;
        uint72 stakedHearts;
        uint72 stakeShares;
        uint16 lockedDay;
        uint16 stakedDays;
        uint16 unlockedDay;
        bool isAutoStake;
    }

    uint256 private nonce;
    uint8 constant private DECIMALS = 8;

    mapping(address => StakeStore[]) public stakeLists;

    event StakeStart(
        uint256 data,
        address indexed stakerAddr,
        uint40 indexed stakeId
    );

    constructor() ERC20("Mock tokens", "HEX") Ownable() { }

    function stakeStart(uint256 newStakedHearts, uint256 newStakedDays)
        external
    {
        require(
            balanceOf(msg.sender) >= newStakedHearts,
            "Insufficient balance"
        );
        _burn(msg.sender, newStakedHearts);

        StakeStore memory newStake;
        newStake.stakedHearts = uint72(newStakedHearts);

        uint40 stakeId = uint40(bytes5(keccak256(
            abi.encodePacked(
                msg.sender,
                newStakedHearts,
                newStakedDays,
                nonce++
            )
        )));
        newStake.stakeId = stakeId;

        uint256 rewardHearts = newStakedHearts * (newStakedDays + 50) / 50;
        require(rewardHearts <= type(uint72).max, "Overflow");
        newStake.stakeShares = uint72(rewardHearts);

        stakeLists[msg.sender].push(newStake);

        emit StakeStart(
            uint256(uint40(block.timestamp))
                | (uint256(uint72(newStakedHearts)) << 40)
                | (uint256(uint72(rewardHearts)) << 112)
                | (uint256(uint16(newStakedDays)) << 184),
            msg.sender,
            stakeId
        );
    }

    function _stakeRemove(StakeStore[] storage stakeList, uint256 stakeIndex)
        internal
    {
        uint256 lastIndex = stakeList.length - 1;

        if (stakeIndex < lastIndex) stakeList[stakeIndex] = stakeList[lastIndex];
        require(stakeIndex <= lastIndex, "something failed");

        stakeList.pop();
    }

    function stakeEnd(uint256 stakeIndex, uint40 stakeIdParam) external {
        require(
            stakeLists[msg.sender].length > stakeIndex,
            "stakeIndex out of bounds"
        );
        require(
            stakeLists[msg.sender][stakeIndex].stakeId == stakeIdParam,
            "Invalid stake parameters"
        );

        _mint(msg.sender, stakeLists[msg.sender][stakeIndex].stakeShares);

        _stakeRemove(stakeLists[msg.sender], stakeIndex);
    }

    function mint(address _recipient, uint256 _amount) external onlyOwner {
        _mint(_recipient, _amount);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function stakeCount(address owner) external view returns (uint256) {
        return stakeLists[owner].length;
    }
}
