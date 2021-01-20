const { accounts, contract } = require('@openzeppelin/test-environment')
const { balance, send, expectEvent, expectRevert } = require('@openzeppelin/test-helpers')
const { ZERO, encodeFunctionCall, ether } = require('./utils/general')
const { BN } = require('bn.js')
const [admin1, admin2, user1, user2, attacker1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const Treasury = contract.fromArtifact('Treasury')
const TestERC20 = contract.fromArtifact('TestERC20')
const TestERC721 = contract.fromArtifact('TestERC721')
const TestERC1155 = contract.fromArtifact('TestERC1155')
const TreasuryTester = contract.fromArtifact('TreasuryTester')

describe('Treasury', () => {
  beforeEach(async () => {
    this.treasury = await Treasury.new({ from: admin1 })
    this.testERC721 = await TestERC721.new('Test NFT', { from: admin1 })
    this.testERC1155 = await TestERC1155.new('', { from: admin1 })
  })
  describe('deploy conditions', () => {
    it('has correct owner', async () => {
      expect(await this.treasury.owner()).to.equal(admin1)
    })
  })
  describe('access restriction', () => {
    beforeEach(async () => {
      send.ether(admin1, this.treasury.address, ether('3.0'))
    })
    it('prevents non-owner from executing calls', async () => {
      await expectRevert(
        this.treasury.callDirect(attacker1, ether('3.0'), '0x', { from: attacker1 }),
        'Ownable: caller is not the owner'
      )
    })
    it('can transfer ownership', async () => {
      const receipt = await this.treasury.transferOwnership(admin2, { from: admin1 })

      expectEvent(receipt, 'OwnershipTransferred', {
        previousOwner: admin1,
        newOwner: admin2
      })

      await expectRevert(
        this.treasury.callDirect(admin1, ether('3.0'), '0x', { from: admin1 }),
        'Ownable: caller is not the owner'
      )

      const userBalTracker = await balance.tracker(user1)
      await userBalTracker.get()

      const treasuryWithdrawAmount = ether('1.0')
      await this.treasury.callDirect(user1, treasuryWithdrawAmount, '0x', { from: admin2 })

      expect(await userBalTracker.delta()).to.be.bignumber.equal(treasuryWithdrawAmount)
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
  describe('arbitrary transaction execution if owner', async () => {
    beforeEach(async () => {
      this.testERC20 = await TestERC20.new('Test token', { from: admin1 })
      this.user1StartAmount = ether('120')
      await this.testERC20.transfer(user1, this.user1StartAmount, { from: admin1 })
      await send.ether(admin1, this.treasury.address, ether('2'))
    })
    it('can send ERC20 tokens', async () => {
      const transferAmount = ether('50')
      await this.testERC20.transfer(this.treasury.address, transferAmount, { from: user1 })

      const callData = encodeFunctionCall(this.testERC20, 'transfer', [user2, transferAmount])
      const receipt = await this.treasury.callDirect(this.testERC20.address, ZERO, callData, {
        from: admin1
      })

      expectEvent.inTransaction(receipt.tx, this.testERC20, 'Transfer', {
        from: this.treasury.address,
        to: user2,
        value: transferAmount
      })
    })
    it('can send native token to payable method', async () => {
      const tester = await TreasuryTester.new()
      const key = await tester.key()
      const requiredAmount = await tester.requiredAmount()

      const callData = encodeFunctionCall(tester, 'access', [key])
      await this.treasury.callDirect(tester.address, requiredAmount, callData, { from: admin1 })
    })
    it('can send ERC721 tokens', async () => {
      const tokenId = new BN('123')
      await this.testERC721.mint(this.treasury.address, tokenId)

      const callData = encodeFunctionCall(this.testERC721, 'safeTransferFrom', [
        this.treasury.address,
        user1,
        tokenId,
        '0x'
      ])
      const receipt = await this.treasury.callDirect(this.testERC721.address, ZERO, callData, {
        from: admin1
      })

      expectEvent.inTransaction(receipt.tx, this.testERC721, 'Transfer', {
        from: this.treasury.address,
        to: user1,
        tokenId: tokenId
      })
    })
    it('can send native token to EOAs', async () => {
      const userBalTracker = await balance.tracker(user1)
      await userBalTracker.get() // set prev

      const transferAmount = ether('1.3')
      await this.treasury.callDirect(user1, transferAmount, '0x', { from: admin1 })

      expect(await userBalTracker.delta()).to.be.bignumber.equal(transferAmount)
    })
  })
})
