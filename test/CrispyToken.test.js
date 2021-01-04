const { accounts, contract } = require('@openzeppelin/test-environment')
const { convertFloatToUQInt } = require('safe-qmath/utils')
const { ZERO, bnToWei } = require('./utils')
const { BN } = require('bn.js')
const [admin1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const CrispyToken = contract.fromArtifact('CrispyToken')

describe('CrispyToken', () => {
  beforeEach(async () => {
    this.maxSupplyWithLoan = bnToWei('10000000000')
    this.flashLoanInterest = convertFloatToUQInt(0.0002)
    this.crispyToken = await CrispyToken.new(this.maxSupplyWithLoan, this.flashLoanInterest, {
      from: admin1
    })
  })
  describe('deploy conditions', () => {
    it('makes deployer owner', async () => {
      expect(await this.crispyToken.owner()).to.equal(admin1)
    })
    it('starts off with a supply of 0', async () => {
      const startSupply = await this.crispyToken.totalSupply()

      expect(startSupply).to.be.bignumber.equal(ZERO)
    })
  })
})
