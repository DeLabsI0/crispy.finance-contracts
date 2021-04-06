const { accounts, contract } = require('@openzeppelin/test-environment')
const { expectEvent, expectRevert, constants, time } = require('@openzeppelin/test-helpers')
const { ZERO_ADDRESS } = constants
const { ZERO, ether, trackBalance, expectEqualWithinError } = require('../utils/general')
const { BN } = require('bn.js')
const [admin1, admin2, user1, user2, attacker1, attacker2] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const VestingCCS = contract.fromArtifact('VestingCCS')
const TestERC20 = contract.fromArtifact('TestERC20')

describe('VestingCCS', () => {
  beforeEach(async () => {
    this.token = await TestERC20.new('Vesting token', { from: admin1 })

    this.vestingStart = await time.latest()
    this.cliffDuration = time.duration.days(60)
    this.vestingCliff = this.vestingStart.add(this.cliffDuration)
    this.vestingTotalDuration = time.duration.years(2)
    this.vestingEnd = await this.vestingStart.add(this.vestingTotalDuration)

    this.vesting = await VestingCCS.new(
      this.token.address,
      this.vestingStart,
      this.vestingCliff,
      this.vestingEnd,
      user1,
      { from: admin1 }
    )
  })
  describe('initial conditions', () => {
    it('starts with vested party having no tokens', async () => {
      expect(await this.token.balanceOf(user1)).to.be.bignumber.equal(ZERO)
    })
    it('starts with correct parameters', async () => {
      expect(await this.vesting.token()).to.equal(this.token.address)
      expect(await this.vesting.beneficiary()).to.equal(user1)
      expect(await this.vesting.totalStillVested()).to.be.bignumber.equal(ZERO)
      expect(await this.vesting.lastRelease()).to.be.bignumber.equal(this.vestingStart)
      expect(await this.vesting.cliff()).to.be.bignumber.equal(this.vestingCliff)
      expect(await this.vesting.vestingEnd()).to.be.bignumber.equal(this.vestingEnd)
    })
    it('emits BeneficiaryUpdated event on construction', async () => {
      await expectEvent.inConstruction(this.vesting, 'BeneficiaryUpdated', {
        prevBeneficiary: ZERO_ADDRESS,
        newBeneficiary: user1
      })
    })
    it('has no pending tokens', async () => {
      expect(await this.vesting.pendingTokens()).to.be.bignumber.equal(ZERO)
      const depositAmount = ether('1000')
      await this.token.transfer(this.vesting.address, depositAmount, { from: admin1 })
      const receipt = await this.vesting.sync(true)
      expectEvent(receipt, 'Deposit', { amount: depositAmount })
      expect(await this.vesting.pendingTokens()).to.be.bignumber.equal(ZERO)
    })
  })
  describe('vested use', () => {
    beforeEach(async () => {
      this.initVestingAmount = ether('1000')
      this.cliffRelease = this.initVestingAmount
        .mul(this.cliffDuration)
        .div(this.vestingTotalDuration)
      this.error = this.initVestingAmount
        .mul(time.duration.seconds(5))
        .div(this.vestingTotalDuration)
      await this.token.transfer(this.vesting.address, this.initVestingAmount, { from: admin1 })
      await this.vesting.sync(true)
    })
    it('stores deposit amount on sync', async () => {
      expect(await this.vesting.totalStillVested()).to.be.bignumber.equal(this.initVestingAmount)
    })
    it('reverts sync without new tokens when revertOnFail set to true', async () => {
      await this.vesting.sync(false)
      await expectRevert(this.vesting.sync(true), 'CCS: Failed to sync')
    })
    it('unlocks larger batch of tokens on cliff', async () => {
      const user1BalTracker = await trackBalance(this.token, user1)

      await time.increaseTo(this.vestingCliff)
      const pendingTokens = await this.vesting.pendingTokens()
      expectEqualWithinError(pendingTokens, this.cliffRelease, this.error)
      expect(await user1BalTracker.delta()).to.be.bignumber.equal(ZERO)
      const receipt = await this.vesting.sync(true)
      expectEvent(receipt, 'Withdraw', {
        recipient: user1,
        amount: (amount) => expectEqualWithinError(amount, this.cliffRelease, this.error)
      })
      expectEvent.notEmitted(receipt, 'Deposit')
      expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
        from: this.vesting.address,
        to: user1,
        value: (amount) => expectEqualWithinError(amount, this.cliffRelease, this.error)
      })
    })
    it('constantly unlocks tokens', async () => {
      await time.increaseTo(this.vestingCliff)

      const timeSkip = time.duration.seconds(1)
      const expectedIncrease = this.initVestingAmount.mul(timeSkip).div(this.vestingTotalDuration)

      let prevPending = await this.vesting.pendingTokens()
      for (let i = 0; i < 10; i++) {
        await time.increase(timeSkip)
        const currentPending = await this.vesting.pendingTokens()
        const diff = currentPending.sub(prevPending)
        expectEqualWithinError(diff, expectedIncrease, this.error)
        prevPending = currentPending
      }
    })
    it('does not account for deposited tokens until sync', async () => {
      const newDeposit = ether('200')
      await this.token.transfer(this.vesting.address, newDeposit, { from: admin1 })
      expect(await this.vesting.totalStillVested()).to.be.bignumber.equal(this.initVestingAmount)
      await time.increaseTo(this.vestingCliff)
      expectEqualWithinError(
        await this.vesting.totalStillVested(),
        this.initVestingAmount,
        this.error
      )
      const receipt = await this.vesting.sync(true)
      expectEvent(receipt, 'Withdraw', {
        recipient: user1,
        amount: (amount) => expectEqualWithinError(amount, this.cliffRelease, this.error)
      })
      expectEvent(receipt, 'Deposit', {
        amount: newDeposit
      })
      expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
        from: this.vesting.address,
        to: user1,
        value: (amount) => expectEqualWithinError(amount, this.cliffRelease, this.error)
      })
      expectEqualWithinError(
        await this.vesting.totalStillVested(),
        this.initVestingAmount.sub(this.cliffRelease).add(newDeposit),
        this.error
      )
    })
    it('correctly tracks pending tokens after vestingEnd', async () => {
      const stopBefore = time.duration.days(2)
      await time.increaseTo(this.vestingEnd.sub(stopBefore))
      let pendingTokens = await this.vesting.pendingTokens()
      let expectedPendingTokens = this.initVestingAmount
        .mul(this.vestingTotalDuration.sub(stopBefore))
        .div(this.vestingTotalDuration)
      expectEqualWithinError(pendingTokens, expectedPendingTokens, this.error)

      const newDeposit = ether('200')
      await this.token.transfer(this.vesting.address, newDeposit, { from: admin1 })
      pendingTokens = await this.vesting.pendingTokens()
      expectEqualWithinError(pendingTokens, expectedPendingTokens, this.error)

      const stopJustBefore = time.duration.seconds(5)
      await time.increaseTo(this.vestingEnd.sub(stopJustBefore))
      pendingTokens = await this.vesting.pendingTokens()
      expectedPendingTokens = this.initVestingAmount
        .mul(this.vestingTotalDuration.sub(stopJustBefore))
        .div(this.vestingTotalDuration)
      expectEqualWithinError(pendingTokens, expectedPendingTokens, this.error)

      await time.increaseTo(this.vestingEnd)
      pendingTokens = await this.vesting.pendingTokens()
      expect(pendingTokens).to.be.bignumber.equal(this.initVestingAmount.add(newDeposit))
    })
  })
  describe('owner functionality', () => {
    beforeEach(async () => {
      this.initVestingAmount = ether('1000')
      this.cliffRelease = this.initVestingAmount
        .mul(this.cliffDuration)
        .div(this.vestingTotalDuration)
      this.error = this.initVestingAmount
        .mul(time.duration.seconds(5))
        .div(this.vestingTotalDuration)
      await this.token.transfer(this.vesting.address, this.initVestingAmount, { from: admin1 })
      await this.vesting.sync(true)
    })
    it('only allows owner to updated beneficiary', async () => {
      await expectRevert(
        this.vesting.changeBeneficiary(attacker2, { from: attacker1 }),
        'Ownable: caller is not the owner'
      )
      const receipt = await this.vesting.changeBeneficiary(user2, { from: admin1 })
      expectEvent(receipt, 'BeneficiaryUpdated', {
        prevBeneficiary: user1,
        newBeneficiary: user2
      })
    })
    it('only allows owner to drain', async () => {
      await expectRevert(
        this.vesting.drain(attacker2, { from: attacker1 }),
        'Ownable: caller is not the owner'
      )
      const receipt = await this.vesting.drain(admin2, { from: admin1 })
      expectEvent(receipt, 'Withdraw', { recipient: admin2, amount: this.initVestingAmount })
      expectEvent(receipt, 'BeneficiaryUpdated', { prevBeneficiary: user1, newBeneficiary: admin2 })
      expectEvent(receipt, 'Drain', { drainedBeneficiary: user1, drainingTo: admin2 })
      expectEvent.notEmitted(receipt, 'Deposit')
    })
    it('credits pending tokens to beneficiary when draining', async () => {
      await time.increaseTo(this.vestingCliff)
      const pendingTokens = await this.vesting.pendingTokens()
      const balTracker = await trackBalance(this.token, user1)
      await this.vesting.drain(admin2, { from: admin1 })
      const delta = await balTracker.delta()
      expectEqualWithinError(delta, pendingTokens, this.error)
    })
  })
})
