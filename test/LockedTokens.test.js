const { accounts, contract } = require('@openzeppelin/test-environment')
const { expectEvent, expectRevert, constants, time } = require('@openzeppelin/test-helpers')
const { ZERO_ADDRESS, MAX_UINT256 } = constants
const { ZERO, ether, trackBalance } = require('./utils/general')
const { BN } = require('bn.js')
const [user1, user2, attacker1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const LockedTokens = contract.fromArtifact('LockedTokens')
const TestERC20 = contract.fromArtifact('TestERC20')

describe('LockedTokens', () => {
  beforeEach(async () => {
    this.tokenLocker = await LockedTokens.new()

    this.token1 = await TestERC20.new('Token 1')
    this.initToken1Amount = ether('21')
    await this.token1.mint(user1, this.initToken1Amount)

    this.token2 = await TestERC20.new('Token 2')
    this.initToken2Amount = ether('34')
    await this.token2.mint(user1, this.initToken2Amount)
  })
  it('can lock and unlock tokens', async () => {
    await this.token1.approve(this.tokenLocker.address, MAX_UINT256, { from: user1 })
    const user1Token1Tracker = await trackBalance(this.token1, user1)
    const user2Token1Tracker = await trackBalance(this.token1, user2)
    const lockerToken1Tracker = await trackBalance(this.token1, this.tokenLocker.address)

    const lockAmount = ether('5')
    const unlockTime = (await time.latest()).add(time.duration.days(7))
    let receipt = await this.tokenLocker.lockTokens(this.token1.address, lockAmount, unlockTime, {
      from: user1
    })
    expectEvent(receipt, 'Transfer', { from: ZERO_ADDRESS, to: user1 })
    expect(await user1Token1Tracker.delta()).to.be.bignumber.equal(lockAmount.neg())
    expect(await lockerToken1Tracker.delta()).to.be.bignumber.equal(lockAmount)

    const { tokenId } = receipt.logs[0].args
    const fetchedInfo = await this.tokenLocker.getLockInfo(tokenId)
    expect(fetchedInfo.token).to.equal(this.token1.address)
    expect(fetchedInfo.amount).to.be.bignumber.equal(lockAmount)
    expect(fetchedInfo.unlockTime).to.be.bignumber.equal(unlockTime)

    await expectRevert(
      this.tokenLocker.unlockTokens(tokenId, { from: attacker1 }),
      'CR3T: Must be owner to redeem'
    )
    await expectRevert(
      this.tokenLocker.unlockTokens(tokenId, { from: user1 }),
      'CR3T: Tokens not unlocked yet'
    )
    await expectRevert(
      this.tokenLocker.unlockTokens(tokenId.add(new BN('1')), { from: user1 }),
      'ERC721: owner query for nonexistent token'
    )

    receipt = await this.tokenLocker.safeTransferFrom(user1, user2, tokenId, { from: user1 })
    expectEvent(receipt, 'Transfer', { from: user1, to: user2, tokenId })

    await time.increaseTo(unlockTime)

    receipt = await this.tokenLocker.unlockTokens(tokenId, { from: user2 })
    expectEvent(receipt, 'Transfer', { from: user2, to: ZERO_ADDRESS, tokenId })
    expect(await user1Token1Tracker.delta()).to.be.bignumber.equal(ZERO)
    expect(await lockerToken1Tracker.delta()).to.be.bignumber.equal(lockAmount.neg())
    expect(await user2Token1Tracker.delta()).to.be.bignumber.equal(lockAmount)
    await expectRevert(
      this.tokenLocker.unlockTokens(tokenId, { from: user2 }),
      'ERC721: owner query for nonexistent token'
    )
  })
})
