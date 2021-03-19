const { accounts, contract } = require('@openzeppelin/test-environment')
const { expectEvent, expectRevert, constants, time } = require('@openzeppelin/test-helpers')
const { ZERO_ADDRESS } = constants
const { ZERO, ether } = require('../utils/general')
const { BN } = require('bn.js')
const [admin1, admin2, user1, attacker1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const CliffConstantStream = contract.fromArtifact('CliffConstantStream')
const TestERC20 = contract.fromArtifact('TestERC20')

describe('CliffConstantStream', () => {
  beforeEach(async () => {
    this.token = await TestERC20.new('Vesting token', { from: admin1 })

    this.vestingStart = await time.latest()
    this.vestingCliff = this.vestingStart.add(time.duration.days(60))
    this.vestingEnd = await this.vestingStart.add(time.duration.years(2))

    this.vesting = await CliffConstantStream.new(
      this.token.address,
      this.vestingStart,
      this.vestingCliff,
      this.vestingEnd,
      user1,
      { from: admin1 }
    )
  })
  describe('initial conditions', () => {
    it('starts with correct parameters', async () => {
      expect(await this.vesting.token()).to.equal(this.token.address)
      expect(await this.vesting.beneficiary()).to.equal(user1)
      expect(await this.vesting.totalStillVested()).to.be.bignumber.equal(ZERO)
      expect(await this.vesting.lastRelease()).to.be.bignumber.equal(this.vestingStart)
      expect(await this.vesting.cliff()).to.be.bignumber.equal(this.vestingCliff)
      expect(await this.vesting.vestingEnd()).to.be.bignumber.equal(this.vestingEnd)
    })
    it('emits BeneficiaryUpdated event on construction', async () => {
      expectEvent.inConstruction(this.vesting, 'BeneficiaryUpdated', {
        prevBeneficiary: ZERO_ADDRESS,
        newBeneficiary: user1
      })
    })
  })
})
