const { accounts, contract } = require('@openzeppelin/test-environment')
const { ZERO } = require('./utils')
const { BN } = require('bn.js')
const [admin1, user1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const CrispyToken = contract.fromArtifact('CrispyToken')

describe('CrispyToken', () => {
  beforeEach(async () => {
    this.crispyToken = await CrispyToken.new({ from: admin1 })
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
  describe('basic ERC20 functions', () => {
    it('can transf')
  })
})
