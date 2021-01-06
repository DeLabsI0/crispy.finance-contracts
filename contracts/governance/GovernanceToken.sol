// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";
import "../utils/ValueSnapshots.sol";

contract GovernanceToken is ERC20 {
    using SafeMath for uint256;
    using ValueSnapshots for ValueSnapshots.Snapshots;

    mapping(address => uint256) internal _delegatedVoteWeight;

    mapping(address => ValueSnapshots.Snapshots) internal _accountVoteWeightsSnapshots;
    ValueSnapshots.Snapshots internal _totalVoteWeightSnapshots;
    uint256 internal _currentSnapshotId;

    mapping(address => address) public delegates;

    event VoteWeightsSnapshot(uint256 id);
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );
    event VoteWeightChanged(
        address indexed delegate,
        uint256 fromVoteWeight,
        uint256 toVoteWeight
    );


    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    { }

    function voteWeightOf(address account) public view returns (uint256) {
        uint256 voteWeight = _delegatedVoteWeight[account];

        if (delegates[account] == address(0)) {
            voteWeight = voteWeight.add(balanceOf(account));
        }

        return voteWeight;
    }

    function totalVoteWeight() public view returns (uint256) {
        return totalSupply();
    }

    function voteWeightOfAt(address account, uint256 snapshotId)
        public view returns (uint256)
    {
        require(snapshotId <= _currentSnapshotId, 'GovernanceToken: invalid id');
        (bool snapshotted, uint256 value) =
            _accountVoteWeightsSnapshots[account].getValueAt(snapshotId);

        return snapshotted ? value : voteWeightOf(account);
    }

    function totalVoteWeightAt(uint256 snapshotId) public view returns (uint256) {
        require(snapshotId <= _currentSnapshotId, 'GovernanceToken: invalid id');
        (bool snapshotted, uint256 value) =
            _totalVoteWeightSnapshots.getValueAt(snapshotId);

        return snapshotted ? value : totalVoteWeight();

    }

    modifier _trackVoteWeightOf(address delegate) {
        uint256 fromVoteWeight = voteWeightOf(delegate);
        _;
        uint256 toVoteWeight = voteWeightOf(delegate);

        if (fromVoteWeight != toVoteWeight) {
            _updateAccountVoteWeightSnapshot(delegate, fromVoteWeight);
            emit VoteWeightChanged(delegate, fromVoteWeight, toVoteWeight);
        }
    }

    function delegateVoteWeightTo(address newDelegate)
        external
        _trackVoteWeightOf(msg.sender)
    {
        address oldDelegate = delegates[msg.sender];
        require(oldDelegate != newDelegate, 'GovToken: Must delegate to new');

        delegates[msg.sender] = newDelegate;
        emit DelegateChanged(msg.sender, oldDelegate, newDelegate);

        uint256 sendersBalance = balanceOf(msg.sender);

        _decreaseDelegatedVoteWeight(oldDelegate, sendersBalance);
        _increaseDelegatedVoteWeight(newDelegate, sendersBalance);
    }

    function _transfer(address sender, address recipient, uint256 amount)
        internal
        virtual
        override
        _trackVoteWeightOf(sender)
        _trackVoteWeightOf(recipient)
    {
        super._transfer(sender, recipient, amount);
    }

    function _mint(address recipient, uint256 amount)
        internal
        virtual
        override
        _trackVoteWeightOf(recipient)
    {
        _updateTotalVoteWeightSnapshot();
        super._mint(recipient, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        virtual
        override
        _trackVoteWeightOf(account)
    {
        _updateTotalVoteWeightSnapshot();
        super._burn(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal virtual override
    {
        super._beforeTokenTransfer(from, to, amount);

        if (amount > 0) {
            if (from != address(0)) {
                _decreaseDelegatedVoteWeight(delegates[from], amount);
            }

            if (to != address(0)) {
                _increaseDelegatedVoteWeight(delegates[to], amount);
            }
        }
    }

    function _increaseDelegatedVoteWeight(
        address delegate,
        uint256 amount
    ) internal {
        if (delegate != address(0)) {
            _setDelegatedVoteWeight(
                delegate,
                _delegatedVoteWeight[delegate].add(amount)
            );
        }
    }

    function _decreaseDelegatedVoteWeight(
        address delegate,
        uint256 amount
    ) internal {
        if (delegate != address(0)) {
            _setDelegatedVoteWeight(
                delegate,
                _delegatedVoteWeight[delegate].sub(amount)
            );
        }
    }

    function _setDelegatedVoteWeight(
        address delegate,
        uint256 newDelegatedVoteWeight
    )
        internal
        _trackVoteWeightOf(delegate)
    {
        _delegatedVoteWeight[delegate] = newDelegatedVoteWeight;
    }

    function _updateAccountVoteWeightSnapshot(
        address account,
        uint256 currentVoteWeight
    ) internal {
        _accountVoteWeightsSnapshots[account].update(
            currentVoteWeight,
            _currentSnapshotId
        );
    }

    function _updateTotalVoteWeightSnapshot() internal {
        _totalVoteWeightSnapshots.update(
            totalVoteWeight(),
            _currentSnapshotId
        );
    }

    function _snapshot() internal returns (uint256) {
        _currentSnapshotId++;

        uint256 currentId = _currentSnapshotId;
        emit VoteWeightsSnapshot(currentId);
        return currentId;
    }
}
