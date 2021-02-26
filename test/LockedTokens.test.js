const { accounts, contract } = require('@openzeppelin/test-environment')
const { expectEvent, expectRevert, constants, time } = require('@openzeppelin/test-helpers')
const { ZERO_ADDRESS, MAX_UINT256 } = constants
const { ZERO, ether, trackBalance, bnSum } = require('./utils/general')
const { BN } = require('bn.js')
const [user1, user2, user3, attacker1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const LockedTokens = contract.fromArtifact('LockedTokens')
const TestERC20 = contract.fromArtifact('TestERC20')

describe('LockedTokens', () => {
  beforeEach(async () => {
    this.tokenLocker = await LockedTokens.new()
    expect(await this.tokenLocker.totalLocksCreated()).to.be.bignumber.equal(ZERO)

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

    expectEvent(receipt, 'Transfer', { from: ZERO_ADDRESS, to: user1, tokenId: new BN('0') })
    expect(await user1Token1Tracker.delta()).to.be.bignumber.equal(lockAmount.neg())
    expect(await lockerToken1Tracker.delta()).to.be.bignumber.equal(lockAmount)

    const { tokenId } = receipt.logs[0].args
    const fetchedInfo = await this.tokenLocker.getLockInfo(tokenId)
    expect(fetchedInfo.token).to.equal(this.token1.address)
    expect(fetchedInfo.amount).to.be.bignumber.equal(lockAmount)
    expect(fetchedInfo.unlockTime).to.be.bignumber.equal(unlockTime)

    await expectRevert(
      this.tokenLocker.unlockTokens(tokenId, { from: attacker1 }),
      'CR3T: Must be owner to unlock'
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
    await expectRevert(
      this.tokenLocker.unlockTokens(tokenId, { from: user1 }),
      'CR3T: Must be owner to unlock'
    )

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
  it('can lock several tokens', async () => {
    const bal = {
      token1: {
        user1: await trackBalance(this.token1, user1),
        user2: await trackBalance(this.token1, user2)
      },
      token2: {
        user1: await trackBalance(this.token2, user1),
        user3: await trackBalance(this.token2, user3)
      }
    }

    await this.token1.approve(this.tokenLocker.address, MAX_UINT256, { from: user1 })
    await this.token2.approve(this.tokenLocker.address, MAX_UINT256, { from: user1 })

    const curTime = await time.latest()

    // first set of lock ups
    const token1Amounts = [ether('8'), ether('6')]
    const token1UnlockTimes = [
      curTime.add(time.duration.days(1)),
      curTime.add(time.duration.days(2))
    ]
    const token1Recipients = [user1, user2]
    let receipt = await this.tokenLocker.spreadLockTokens(
      this.token1.address,
      token1Amounts,
      token1UnlockTimes,
      token1Recipients,
      { from: user1 }
    )
    expectEvent(receipt, 'Transfer', {
      from: ZERO_ADDRESS,
      to: token1Recipients[0],
      tokenId: new BN('0')
    })
    expect(await this.tokenLocker.ownerOf(new BN('0'))).to.equal(token1Recipients[0])
    let lock = await this.tokenLocker.getLockInfo(new BN('0'))
    expect(lock.token).to.equal(this.token1.address)
    expect(lock.amount).to.be.bignumber.equal(token1Amounts[0])
    expect(lock.unlockTime).to.be.bignumber.equal(token1UnlockTimes[0])

    expectEvent(receipt, 'Transfer', {
      from: ZERO_ADDRESS,
      to: token1Recipients[1],
      tokenId: new BN('1')
    })
    expect(await this.tokenLocker.totalLocksCreated()).to.be.bignumber.equal(new BN('2'))
    expect(await this.tokenLocker.ownerOf(new BN('1'))).to.equal(token1Recipients[1])
    lock = await this.tokenLocker.getLockInfo(new BN('1'))
    expect(lock.token).to.equal(this.token1.address)
    expect(lock.amount).to.be.bignumber.equal(token1Amounts[1])
    expect(lock.unlockTime).to.be.bignumber.equal(token1UnlockTimes[1])

    expect(await this.tokenLocker.totalLocksCreated()).to.be.bignumber.equal(new BN('2'))
    expect(await bal.token1.user1.delta()).to.be.bignumber.equal(bnSum(...token1Amounts).neg())

    // second set of lock ups
    const token2Amounts = [ether('4'), ether('7'), ether('5')]
    const token2UnlockTimes = [
      curTime.add(time.duration.hours(9)),
      curTime.add(time.duration.days(4)),
      curTime.add(time.duration.hours(13))
    ]
    const token2Recipients = [user2, user1, user3]
    receipt = await this.tokenLocker.spreadLockTokens(
      this.token2.address,
      token2Amounts,
      token2UnlockTimes,
      token2Recipients,
      { from: user1 }
    )

    expectEvent(receipt, 'Transfer', {
      from: ZERO_ADDRESS,
      to: token2Recipients[0],
      tokenId: new BN('2')
    })
    expect(await this.tokenLocker.totalLocksCreated()).to.be.bignumber.equal(new BN('5'))
    expect(await this.tokenLocker.ownerOf(new BN('2'))).to.equal(token2Recipients[0])
    lock = await this.tokenLocker.getLockInfo(new BN('2'))
    expect(lock.token).to.equal(this.token2.address)
    expect(lock.amount).to.be.bignumber.equal(token2Amounts[0])
    expect(lock.unlockTime).to.be.bignumber.equal(token2UnlockTimes[0])

    expectEvent(receipt, 'Transfer', {
      from: ZERO_ADDRESS,
      to: token2Recipients[1],
      tokenId: new BN('3')
    })
    expect(await this.tokenLocker.ownerOf(new BN('3'))).to.equal(token2Recipients[1])
    lock = await this.tokenLocker.getLockInfo(new BN('3'))
    expect(lock.token).to.equal(this.token2.address)
    expect(lock.amount).to.be.bignumber.equal(token2Amounts[1])
    expect(lock.unlockTime).to.be.bignumber.equal(token2UnlockTimes[1])

    expectEvent(receipt, 'Transfer', {
      from: ZERO_ADDRESS,
      to: token2Recipients[2],
      tokenId: new BN('4')
    })
    expect(await this.tokenLocker.ownerOf(new BN('4'))).to.equal(token2Recipients[2])
    lock = await this.tokenLocker.getLockInfo(new BN('4'))
    expect(lock.token).to.equal(this.token2.address)
    expect(lock.amount).to.be.bignumber.equal(token2Amounts[2])
    expect(lock.unlockTime).to.be.bignumber.equal(token2UnlockTimes[2])

    expect(await this.tokenLocker.totalLocksCreated()).to.be.bignumber.equal(new BN('5'))
    expect(await bal.token2.user1.delta()).to.be.bignumber.equal(bnSum(...token2Amounts).neg())

    // unlocking
    await time.increaseTo(token1UnlockTimes[1])
    receipt = await this.tokenLocker.unlockTokens(new BN('1'), { from: user2 })
    expectEvent(receipt, 'Transfer', {
      from: user2,
      to: ZERO_ADDRESS,
      tokenId: new BN('1')
    })
    expect(await bal.token1.user2.delta()).to.be.bignumber.equal(token1Amounts[1])

    await time.increaseTo(token2UnlockTimes[1])
    receipt = await this.tokenLocker.safeTransferFrom(user1, user3, new BN('3'), { from: user1 })
    expectEvent(receipt, 'Transfer', { from: user1, to: user3, tokenId: new BN('3') })
    await expectRevert(
      this.tokenLocker.unlockTokens(new BN('3'), { from: user1 }),
      'CR3T: Must be owner to unlock'
    )
    receipt = await this.tokenLocker.unlockTokens(new BN('3'), { from: user3 })
    expectEvent(receipt, 'Transfer', { from: user3, to: ZERO_ADDRESS, tokenId: new BN('3') })
    expect(await bal.token2.user3.delta()).to.be.bignumber.equal(token2Amounts[1])
  })
  it('can mint single directly to another address', async () => {
    await this.token1.transfer(user2, ether('20'), { from: user1 })
    await this.token1.approve(this.tokenLocker.address, MAX_UINT256, { from: user2 })

    const user2Tracker = await trackBalance(this.token1, user2)
    const user3Tracker = await trackBalance(this.token1, user3)

    const lockAmount = ether('19')
    const lockTime = (await time.latest()).add(time.duration.days(2))

    expect(await this.tokenLocker.totalLocksCreated()).to.be.bignumber.equal(ZERO)
    await this.tokenLocker.lockTokensFor(this.token1.address, lockAmount, lockTime, user3, {
      from: user2
    })
    expect(await this.tokenLocker.totalLocksCreated()).to.be.bignumber.equal(new BN('1'))
    expect(await this.tokenLocker.ownerOf(new BN('0'))).to.equal(user3)
    expect(await user2Tracker.delta()).to.be.bignumber.equal(lockAmount.neg())
    expect(await user3Tracker.delta()).to.be.bignumber.equal(ZERO)

    await expectRevert(
      this.tokenLocker.unlockTokens(new BN('0'), { from: user2 }),
      'CR3T: Must be owner to unlock'
    )
    await expectRevert(
      this.tokenLocker.unlockTokens(new BN('0'), { from: user3 }),
      'CR3T: Tokens not unlocked yet'
    )

    await time.increaseTo(lockTime)
    const receipt = await this.tokenLocker.unlockTokens(new BN('0'), { from: user3 })
    expectEvent(receipt, 'Transfer', { from: user3, to: ZERO_ADDRESS, tokenId: new BN('0') })
    expect(await user2Tracker.delta()).to.be.bignumber.equal(ZERO)
    expect(await user3Tracker.delta()).to.be.bignumber.equal(lockAmount)
  })
  describe('gas usage', () => {
    it('direct lock', async () => {
      await this.token1.approve(this.tokenLocker.address, MAX_UINT256, { from: user1 })
      const lockTime = (await time.latest()).add(time.duration.days(10))
      const { receipt } = await this.tokenLocker.lockTokens(
        this.token1.address,
        ether('0.5'),
        lockTime,
        { from: user1 }
      )
      console.log(`direct lock gas usage: ${receipt.gasUsed} (${receipt.cumulativeGasUsed})`)
    })
    it('lock to another recipient', async () => {
      await this.token1.approve(this.tokenLocker.address, MAX_UINT256, { from: user1 })
      const lockTime = (await time.latest()).add(time.duration.days(10))
      const { receipt } = await this.tokenLocker.lockTokensFor(
        this.token1.address,
        ether('0.5'),
        lockTime,
        user2,
        { from: user1 }
      )
      console.log(
        `lock to external recipient gas usage: ${receipt.gasUsed} (${receipt.cumulativeGasUsed})`
      )
    })
    it('multi-lock gas usage', async () => {
      await this.token1.approve(this.tokenLocker.address, MAX_UINT256, { from: user1 })
      const lock = async (lockNum) => {
        const amount = ether('0.5')
        const recipient = user2
        const lockTime = (await time.latest()).add(time.duration.days(10))

        const amounts = []
        const recipients = []
        const lockTimes = []

        for (let i = 0; i < lockNum; i++) {
          amounts.push(amount)
          recipients.push(recipient)
          lockTimes.push(lockTime)
        }

        return await this.tokenLocker.spreadLockTokens(
          this.token1.address,
          amounts,
          lockTimes,
          recipients,
          { from: user1 }
        )
      }

      console.log('multi-lock gas usage:')

      let locks = 1
      const { receipt: receipt1 } = await lock(locks)
      console.log(`(${locks}) => ${receipt1.gasUsed} (${receipt1.gasUsed / locks} gas / lock)`)

      locks = 3
      const { receipt: receipt2 } = await lock(locks)
      console.log(`(${locks}) => ${receipt2.gasUsed} (${receipt2.gasUsed / locks} gas / lock)`)

      locks = 10
      const { receipt: receipt3 } = await lock(locks)
      console.log(`(${locks}) => ${receipt3.gasUsed} (${receipt3.gasUsed / locks} gas / lock)`)

      locks = 20
      const { receipt: receipt4 } = await lock(locks)
      console.log(`(${locks}) => ${receipt4.gasUsed} (${receipt4.gasUsed / locks} gas / lock)`)
    })
    it('unlock gas usage', async () => {
      await this.token1.approve(this.tokenLocker.address, MAX_UINT256, { from: user1 })
      const curTime = await time.latest()
      const unlockTime = curTime.add(time.duration.days(1))
      await this.tokenLocker.lockTokens(this.token1.address, ether('2'), unlockTime, {
        from: user1
      })
      await time.increaseTo(unlockTime)

      const { receipt } = await this.tokenLocker.unlockTokens(new BN('0'), { from: user1 })
      console.log(`unlock lock gas usage: ${receipt.gasUsed} (${receipt.cumulativeGasUsed})`)
    })
  })
})
