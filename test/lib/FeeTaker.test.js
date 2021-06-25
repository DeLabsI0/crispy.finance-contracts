const { contract, accounts } = require('@openzeppelin/test-environment')
const { constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers')
const { ZERO_ADDRESS, MAX_UINT256 } = constants
const { expect } = require('chai')
const { trackBalance, ether, safeBN, ZERO, getFee } = require('../utils/general')

const FeeTaker = contract.fromArtifact('FeeTakerMock')
const TestERC20 = contract.fromArtifact('TestERC20')
const [admin1, admin2, user, attacker] = accounts

describe('FeeTaker', () => {
  before(async () => {
    this.fee = ether('0.20')
    this.feeTaker = await FeeTaker.new(this.fee, { from: admin1 })

    this.token = await TestERC20.new('test token')
    await this.token.mint(user, ether('10'))
    await this.token.approve(this.feeTaker.address, MAX_UINT256, { from: user })
  })
  describe('start conditions', () => {
    it('emits fee set event', async () => {
      await expectEvent.inConstruction(this.feeTaker, 'FeeSet', { setter: admin1, fee: this.fee })
    })
    it('has correct scale', async () => {
      this.scale = await this.feeTaker.SCALE()
      expect(this.scale).to.be.bignumber.equal(safeBN('1000000000000000000'))
    })
    it('has correct start fee', async () => {
      expect(await this.feeTaker.fee()).to.be.bignumber.equal(this.fee)
    })
    it('has correct start owner', async () => {
      expect(await this.feeTaker.owner()).to.equal(admin1)
    })
    it('has no accounted fees', async () => {
      expect(await this.feeTaker.accountedFees(ZERO_ADDRESS)).to.be.bignumber.equal(ZERO)
      expect(await this.feeTaker.accountedFees(this.token.address)).to.be.bignumber.equal(ZERO)
    })
  })
  describe('direct fee accounting', () => {
    it('accounts native token fees', async () => {
      const deposit = ether('1')
      const userTracker = await trackBalance(null, user)
      const takerTracker = await trackBalance(null, this.feeTaker.address)
      const receipt = await this.feeTaker.depositEthFee({ from: user, value: deposit })
      const txFee1 = await getFee(receipt)
      expectEvent(receipt, 'AccountedFee', { token: ZERO_ADDRESS, amount: deposit })
      expect(await userTracker.delta()).to.be.bignumber.equal(
        deposit.add(txFee1).neg(),
        'user delta'
      )
      expect(await takerTracker.delta()).to.be.bignumber.equal(deposit, 'fee taker delta')
      expect(await this.feeTaker.accountedFees(ZERO_ADDRESS)).to.be.bignumber.equal(deposit)
    })
    it('accounts ERC20 fees', async () => {
      const deposit = ether('1')
      const token = this.token.address
      const userTracker = await trackBalance(this.token, user)
      const takerTracker = await trackBalance(this.token, this.feeTaker.address)
      const receipt = await this.feeTaker.depositERC20Fee(deposit, token, {
        from: user
      })
      expectEvent(receipt, 'AccountedFee', { token, amount: deposit })
      expect(await userTracker.delta()).to.be.bignumber.equal(deposit.neg(), 'user delta')
      expect(await takerTracker.delta()).to.be.bignumber.equal(deposit, 'fee taker delta')
      expect(await this.feeTaker.accountedFees(token)).to.be.bignumber.equal(deposit)
    })
  })
  describe('calculation based fee taking', () => {
    it('takes correct fee', async () => {
      const amount = ether('2')
      const expectedFee = ether('0.4')
      const userTracker = await trackBalance(this.token, user)
      const feeTaker = this.feeTaker.address
      const feeTakerTracker = await trackBalance(this.token, feeTaker)
      const token = this.token.address
      const receipt = await this.feeTaker.takeFeeFrom(amount, token, { from: user })
      expectEvent(receipt, 'AccountedFee', { token, amount: expectedFee })
      await expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
        from: user,
        to: feeTaker,
        value: amount
      })
      await expectEvent.inTransaction(receipt.tx, this.token, 'Transfer', {
        from: feeTaker,
        to: user,
        value: amount.sub(expectedFee)
      })
      expect(await userTracker.delta()).to.be.bignumber.equal(expectedFee.neg())
      expect(await feeTakerTracker.delta()).to.be.bignumber.equal(expectedFee)
    })
    it('adds correct fee to total', async () => {
      const total = ether('2')
      const userTracker = await trackBalance(this.token, user)
      const token = this.token.address
      const receipt = await this.feeTaker.addFeeToTotal(total, token, { from: user })
      const addedFee = (await userTracker.delta()).neg() // is negative so need to flip the sign
      expect(addedFee.mul(this.scale).div(total.add(addedFee))).to.be.bignumber.equal(this.fee)
      expectEvent(receipt, 'AccountedFee', { token, amount: addedFee })
    })
  })
  describe('utils', () => {
    it('prevents fee from being higher', async () => {
      await expectRevert(
        this.feeTaker.checkFeeAtMost(this.fee.sub(safeBN(1))),
        'FeeTaker: Fee too high'
      )
      await this.feeTaker.checkFeeAtMost(this.fee.add(safeBN(1)))
    })
    it('requires fee to be equal', async () => {
      await expectRevert(
        this.feeTaker.checkFeeEqual(this.fee.add(safeBN(1))),
        'FeeTaker: Wrong fee'
      )
      await this.feeTaker.checkFeeEqual(this.fee)
    })
  })
  describe('owner functions', async () => {
    it('only allows owner to set fee', async () => {
      await expectRevert(
        this.feeTaker.setFee(ZERO, { from: attacker }),
        'Ownable: caller is not the owner'
      )
      const newFee = ether('0.08')
      const receipt = await this.feeTaker.setFee(newFee, { from: admin1 })
      expectEvent(receipt, 'FeeSet', { fee: newFee })
    })
    it('disallows non-owner from withdrawing ERC20 fees', async () => {
      const token = this.token.address
      const availableBalance = await this.feeTaker.accountedFees(token)
      await expectRevert(
        this.feeTaker.withdrawFeesTo(attacker, availableBalance, token, { from: attacker }),
        'Ownable: caller is not the owner'
      )
    })
    it('disallows withdrawing more than accounted fees', async () => {
      const token = this.token.address
      const availableBalance = await this.feeTaker.accountedFees(token)
      const toWithdraw = availableBalance.add(safeBN(1))
      await expectRevert(
        this.feeTaker.withdrawFeesTo(admin1, toWithdraw, token, { from: admin1 }),
        'FeeTaker: Insufficient fees'
      )
    })
    it('allows owner to withdraw ERC20 fees', async () => {
      const token = this.token.address
      const availableBalance = await this.feeTaker.accountedFees(token)
      const withdraw1 = availableBalance.div(safeBN(3))
      const admin1Tracker = await trackBalance(this.token, admin1)
      const withdraw2 = availableBalance.sub(withdraw1)
      const admin2Tracker = await trackBalance(this.token, admin2)
      const feeTakerTracker = await trackBalance(this.token, this.feeTaker.address)

      const receipt1 = await this.feeTaker.withdrawFeesTo(admin1, withdraw1, token, {
        from: admin1
      })
      expectEvent(receipt1, 'FeesWithdrawn', {
        withdrawer: admin1,
        recipient: admin1,
        token,
        amount: withdraw1
      })
      expect(await admin1Tracker.delta()).to.be.bignumber.equal(withdraw1)
      expect(await admin2Tracker.delta()).to.be.bignumber.equal(ZERO)
      expect(await feeTakerTracker.delta()).to.be.bignumber.equal(withdraw1.neg())
      expect(await this.feeTaker.accountedFees(token)).to.be.bignumber.equal(
        availableBalance.sub(withdraw1)
      )

      const receipt2 = await this.feeTaker.withdrawFeesTo(admin2, withdraw2, token, {
        from: admin1
      })
      expectEvent(receipt2, 'FeesWithdrawn', {
        withdrawer: admin1,
        recipient: admin2,
        token,
        amount: withdraw2
      })
      expect(await admin1Tracker.delta()).to.be.bignumber.equal(ZERO)
      expect(await admin2Tracker.delta()).to.be.bignumber.equal(withdraw2)
      expect(await feeTakerTracker.delta()).to.be.bignumber.equal(withdraw2.neg())
      expect(await this.feeTaker.accountedFees(token)).to.be.bignumber.equal(
        availableBalance.sub(withdraw1).sub(withdraw2)
      )
    })
    it('allows owner to withdraw native fees', async () => {
      await this.feeTaker.transferOwnership(admin2, { from: admin1 })
      const admin1Tracker = await trackBalance(null, admin1)
      const admin2Tracker = await trackBalance(null, admin2)
      const feeTakerTracker = await trackBalance(null, this.feeTaker.address)
      const availableFees = await this.feeTaker.accountedFees(ZERO_ADDRESS)
      const receipt = await this.feeTaker.withdrawFeesTo(admin1, availableFees, ZERO_ADDRESS, {
        from: admin2
      })
      expectEvent(receipt, 'FeesWithdrawn', {
        withdrawer: admin2,
        recipient: admin1,
        token: ZERO_ADDRESS,
        amount: availableFees
      })
      const txFee = await getFee(receipt)
      expect(await admin1Tracker.delta()).to.be.bignumber.equal(availableFees)
      expect(await admin2Tracker.delta()).to.be.bignumber.equal(txFee.neg())
      expect(await feeTakerTracker.delta()).to.be.bignumber.equal(availableFees.neg())
    })
  })
})
