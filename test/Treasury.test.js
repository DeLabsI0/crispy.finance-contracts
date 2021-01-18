const { accounts, contract } = require('@openzeppelin/test-environment')
const { constants, balance, ether, send } = require('@openzeppelin/test-helpers')
const { ZERO_ADDRESS } = constants
const { encodeFunctionCall } = require('./utils')
const { BN } = require('bn.js')
const [admin1, admin2, user1, user2, attacker1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const Treasury = contract.fromArtifact('Treasury')
const TestERC20 = contract.fromArtifact('TestERC20')
const TestERC721 = contract.fromArtifact('TestERC721')
const TestERC1155 = contract.fromArtifact('TestERC1155')

describe('Treasury', () => {
  beforeEach(async () => {
    this.treasury = await Treasury.new(admin1, { from: admin2 })
    this.testERC721 = await TestERC721.new('Test NFT', { from: admin1 })
    this.testERC1155 = await TestERC1155.new('', { from: admin1 })
  })
  describe('deploy conditions', () => {
    it('has correct owner', async () => {
      expect(await this.treasury.owner()).to.equal(admin1)
    })
  })
  describe('asset receival', () => {
    it('accepts native token (mainnet: ether, xDai: xDai)', async () => {
      const treasuryBalTracker = await balance.tracker(this.treasury.address, 'wei')
      await treasuryBalTracker.get()

      const amountToSend = ether('1.2')
      await send.ether(user1, this.treasury.address, amountToSend)

      expect(await treasuryBalTracker.delta()).to.be.bignumber.equal(amountToSend)
    })
    it('accepts ERC721 tokens', async () => {
      const tokenId = new BN('1234')
      await this.testERC721.mint(user1, tokenId, { from: admin1 })
      await this.testERC721.safeTransferFrom(user1, this.treasury.address, tokenId, { from: user1 })
      expect(await this.testERC721.ownerOf(tokenId)).to.equal(this.treasury.address)
    })
    it('accepts ERC1155 tokens', async () => {
      const tokenId = new BN('5678')
      await this.testERC1155.mint(user1, tokenId, new BN('112'), { from: admin1 })

      const treasuryDonation = new BN('78')
      await this.testERC1155.safeTransferFrom(
        user1,
        this.treasury.address,
        tokenId,
        treasuryDonation,
        '0x',
        { from: user1 }
      )

      const treasuryTokenBal = await this.testERC1155.balanceOf(this.treasury.address, tokenId)
      expect(treasuryTokenBal).to.be.bignumber.equal(treasuryDonation)
    })
  })
  describe('arbitrary transaction execution', async () => {
    beforeEach(async () => {
      this.testERC20 = await TestERC20.new('Test token', { from: admin1 })
      this.user1StartAmount = ether('120')
      await this.testERC20.transfer(user1, this.user1StartAmount, { from: admin1 })
      await send.ether(admin1, this.treasury.address, ether('2'))
    })
    it('can callDirect to send ERC20 tokens', async () => {
      const transferAmount = ether('50')
      encodeFunctionCall(this.testERC20, 'transfer', [user2, transferAmount])
      /*
0xa9059cbb
00000000000000000000000035e45bc0488a820ad5c4f43fcb1e8632cbf9674c
000000000000000000000000000000000000000000000002b5e3af16b1880000


        */

      // const data = this.testERC20.methods.transfer(user2, transferAmount).encodeABI()
      // console.log('data: ', data)
    })
  })
})
