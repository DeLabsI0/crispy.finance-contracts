const { accounts, contract } = require('@openzeppelin/test-environment')
const { expectEvent, expectRevert, constants, time } = require('@openzeppelin/test-helpers')
const { ZERO_ADDRESS } = constants
const { ZERO, bnToWei } = require('./utils')
const { BN } = require('bn.js')
const [admin1, admin2, user1, user2, attacker1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const CrispyToken = contract.fromArtifact('CrispyToken')

describe('CrispyToken', () => {
  beforeEach(async () => {
    this.crispyToken = await CrispyToken.new({ from: admin1 })
    this.HARD_CAP = await this.crispyToken.HARD_CAP()
  })
  describe('deploy conditions', () => {
    it('makes deployer owner', async () => {
      const owner = await this.crispyToken.owner()
      expect(attacker1).to.not.equal(admin1)
      expect(owner).to.equal(admin1)
      expect(owner).to.not.equal(attacker1)
    })
    it('starts off with a supply of 0', async () => {
      const startSupply = await this.crispyToken.totalSupply()

      expect(startSupply).to.be.bignumber.equal(ZERO)
    })
    it('addresses start with no balance', async () => {
      const userStartBalance = await this.crispyToken.balanceOf(user1)
      expect(userStartBalance).to.be.bignumber.equal(ZERO)
    })
  })
  describe('admin functionality', () => {
    it('can only mint tokens if owner', async () => {
      const mintAmount = bnToWei('34.5')
      const receipt = await this.crispyToken.mint(user1, mintAmount, { from: admin1 })
      expectEvent(receipt, 'Transfer', {
        from: ZERO_ADDRESS,
        to: user1,
        value: mintAmount
      })

      const balAfterMint = await this.crispyToken.balanceOf(user1)
      expect(balAfterMint).to.be.bignumber.equal(mintAmount)

      await expectRevert(
        this.crispyToken.mint(attacker1, bnToWei('100'), { from: attacker1 }),
        'Ownable: caller is not the owner'
      )
    })
    it('cannot mint beyond hard cap', async () => {
      expect(this.HARD_CAP).to.be.bignumber.equal(bnToWei(400 * 1e6))

      const initialInjection = bnToWei(390 * 1e6)
      await this.crispyToken.mint(admin2, initialInjection, { from: admin1 })

      const overCapInjection = bnToWei(50 * 1e6)
      const totalAttemptedInjection = initialInjection.add(overCapInjection)
      expect(totalAttemptedInjection).to.be.bignumber.above(this.HARD_CAP)

      await expectRevert(
        this.crispyToken.mint(admin1, overCapInjection, { from: admin1 }),
        'ERC20Capped: cap exceeded'
      )
    })
    it('can transfer ownership if owner', async () => {
      const receipt = await this.crispyToken.transferOwnership(admin2, { from: admin1 })
      expectEvent(receipt, 'OwnershipTransferred', { previousOwner: admin1, newOwner: admin2 })

      const newCurrentOwner = await this.crispyToken.owner()
      expect(newCurrentOwner).to.equal(admin2)
      expect(newCurrentOwner).to.not.equal(admin1)

      await expectRevert(
        this.crispyToken.transferOwnership(admin1, { from: admin1 }),
        'Ownable: caller is not the owner'
      )
      await expectRevert(
        this.crispyToken.transferOwnership(attacker1, { from: attacker1 }),
        'Ownable: caller is not the owner'
      )
    })
  })
  describe('balances time locks', () => {
    beforeEach(async () => {
      const currentTime = await time.latest()
      this.unlockTime = currentTime.add(time.duration.days(60))

      const receipt = await this.crispyToken.lockBalanceUntil(this.unlockTime, {
        from: user1
      })
      expectEvent(receipt, 'BalanceLocked', { account: user1, unlockTime: this.unlockTime })

      expect(await this.crispyToken.unlockTimes(user1)).to.be.bignumber.equal(this.unlockTime)
    })
    it('allows timelocked accounts to receive tokens', async () => {
      const mintAmount = bnToWei('43')
      await this.crispyToken.mint(user2, mintAmount, { from: admin1 })

      const receipt = await this.crispyToken.transfer(user1, mintAmount, { from: user2 })
      expectEvent(receipt, 'Transfer', { from: user2, to: user1, value: mintAmount })
    })
    it('prevents locked users from transferring', async () => {
      const user1Bal = bnToWei('17')
      await this.crispyToken.mint(user1, user1Bal, { from: admin1 })

      await expectRevert(
        this.crispyToken.transfer(user2, user1Bal, { from: user1 }),
        'CRSPY: Balance locked'
      )
    })
    it('can increase lock time while locked', async () => {
      const lockIncrease = time.duration.days(10)
      const newUnlockTime = this.unlockTime.add(lockIncrease)

      const receipt = await this.crispyToken.lockBalanceUntil(newUnlockTime, {
        from: user1
      })

      expectEvent(receipt, 'BalanceLocked', { account: user1, unlockTime: newUnlockTime })
      expect(await this.crispyToken.unlockTimes(user1)).to.be.bignumber.equal(newUnlockTime)
    })
    it('cannot decrease lock time while locked', async () => {
      const beforeUnlockTime = this.unlockTime.sub(time.duration.seconds(1))
      await expectRevert(
        this.crispyToken.lockBalanceUntil(beforeUnlockTime, { from: user1 }),
        'CRSPY: Invalid unlock time'
      )
    })
    it('can moves tokens after timelock expiry', async () => {
      const user1Bal = bnToWei('17')
      await this.crispyToken.mint(user1, user1Bal, { from: admin1 })
      await time.increaseTo(this.unlockTime)

      const receipt = await this.crispyToken.transfer(user2, user1Bal, { from: user1 })

      expectEvent(receipt, 'Transfer', { from: user1, to: user2, value: user1Bal })
    })
    it('cannot set unlock time in the past', async () => {
      const currentTime = await time.latest()
      const unlockTimeInThePast = currentTime.sub(time.duration.seconds(1))
      await expectRevert(
        this.crispyToken.lockBalanceUntil(unlockTimeInThePast, { from: user2 }),
        'CRSPY: Unlock time passed'
      )
    })
  })
})
