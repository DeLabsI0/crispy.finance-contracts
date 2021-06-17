const { accounts, contract, web3 } = require('@openzeppelin/test-environment')
const { expectRevert, expectEvent, constants } = require('@openzeppelin/test-helpers')
const { MAX_UINT256, ZERO_ADDRESS } = constants
const { ether, trackBalance } = require('../utils/general')
const [admin, attacker, user1, user2, user3] = accounts
const BN = require('bn.js')
const { expect } = require('chai')

const HexStakeTokenizer = contract.fromArtifact('HexStakeTokenizer')
const HexMock = contract.fromArtifact('HexMock')

describe('HexStakeTokenizer', () => {
  const hexTokens = (amount) => ether(amount, 'gwei').div(new BN('10'))
  before(async () => {
    this.hex = await HexMock.new({ from: admin })
    this.fee = ether('0.01')
    this.staker = await HexStakeTokenizer.new(this.fee, this.hex.address, { from: admin })
  })
  it('deploy gas cost', async () => {
    const txid = this.staker.transactionHash
    const { gasUsed } = await web3.eth.getTransactionReceipt(txid)
    console.log(
      `deploy gas cost: ${Intl.NumberFormat('en-us', { maximumFractionDigits: 3 }).format(gasUsed)}`
    )
    this.scale = await this.staker.SCALE()
  })
  describe('owner functionality', () => {
    it('only allows owner to set fee ', async () => {
      expect(await this.staker.fee()).to.be.bignumber.equal(this.fee)
      await expectRevert(
        this.staker.setFee(ether('1.00'), { from: attacker }),
        'Ownable: caller is not the owner'
      )
      this.fee = this.fee.div(new BN('2'))
      const receipt = await this.staker.setFee(this.fee, { from: admin })
      expectEvent(receipt, 'FeeSet', { setter: admin, fee: this.fee })
      expect(await this.staker.fee()).to.be.bignumber.equal(this.fee)
    })
    it('only allows owner to set base URI', async () => {
      expect(await this.staker.currentBaseURI()).to.equal('')
      await expectRevert(
        this.staker.setBaseURI('some bad URI', { from: attacker }),
        'Ownable: caller is not the owner'
      )
      const newURI = 'https://some new uri'
      await this.staker.setBaseURI(newURI, { from: admin })
      expect(await this.staker.currentBaseURI()).to.equal(newURI)
    })
  })
  describe('normal stake creation and use', () => {
    it('disallows stake creation if fee changed', async () => {
      const feePreChange = this.fee
      this.fee = this.fee.mul(new BN('2'))
      await this.staker.setFee(this.fee, { from: admin })
      await expectRevert(
        this.staker.createStake(ether('20'), 20, feePreChange, { from: user1 }),
        'FeeTaker: fee too high'
      )
    })
    it('disallows stake creation if user does not have sufficient funds', async () => {
      await expectRevert(
        this.staker.createStake(ether('20'), 20, this.fee, { from: user1 }),
        'ERC20: transfer amount exceeds balance'
      )
    })
    it('disallows stake creation if user did not approve staker contract', async () => {
      this.stakeAmount = hexTokens('6000')
      await this.hex.mint(user1, this.stakeAmount, { from: admin })
      await expectRevert(
        this.staker.createStake(this.stakeAmount, 20, this.fee, { from: user1 }),
        'ERC20: transfer amount exceeds allowance'
      )
    })
    it('allows user to create stake', async () => {
      await this.hex.approve(this.staker.address, MAX_UINT256, { from: user1 })
      const receipt = await this.staker.createStake(this.stakeAmount, 20, this.fee, { from: user1 })
      const tokenId = new BN('0')
      expectEvent(receipt, 'Transfer', {
        from: ZERO_ADDRESS,
        to: user1,
        tokenId
      })
      expectEvent(receipt, 'AccountedFee', {
        token: this.hex.address,
        amount: this.stakeAmount.mul(this.fee).div(this.scale)
      })
      expect(await this.staker.balanceOf(user1)).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.ownerOf(tokenId)).to.equal(user1)
      expect(await this.hex.stakeCount(this.staker.address)).to.be.bignumber.equal(new BN('1'))
      const stakeIndex = new BN('0')
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      expect(await this.staker.totalSupply()).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('1'))
    })
    it('only allows stake owner to unstake', async () => {
      const tokenId = new BN('0')
      await expectRevert(this.staker.unstake(tokenId, { from: attacker }), 'CHXS: Not token owner')
      const balTracker = await trackBalance(this.hex, user1)
      const { stakeShares: stakeYield } = await this.hex.stakeLists(
        this.staker.address,
        new BN('0')
      )
      const receipt = await this.staker.unstake(tokenId, { from: user1 })
      expectEvent(receipt, 'Transfer', {
        from: user1,
        to: ZERO_ADDRESS,
        tokenId
      })
      expect(await this.staker.balanceOf(user1)).to.be.bignumber.equal(new BN('0'))
      expect(await this.staker.totalSupply()).to.be.bignumber.equal(new BN('0'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('1'))
      expect(await balTracker.delta()).to.be.bignumber.equal(stakeYield)
      expect(await this.hex.stakeCount(this.staker.address)).to.be.bignumber.equal(new BN('0'))
    })
    it('allows user to create a stake for another address', async () => {
      const stakeAmount = hexTokens('1000')
      await this.hex.mint(user1, stakeAmount, { from: admin })
      const receipt = await this.staker.createStakeFor(user2, stakeAmount, 20, this.fee, {
        from: user1
      })
      const tokenId = new BN('1')
      expectEvent(receipt, 'Transfer', { from: ZERO_ADDRESS, to: user2, tokenId })
      expect(await this.staker.balanceOf(user2)).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.ownerOf(tokenId)).to.equal(user2)
      const stakeIndex = new BN('0')
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      expect(await this.staker.totalSupply()).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('2'))
    })
    it('allows transfer of stake', async () => {
      const tokenId = new BN('1')
      const receipt = await this.staker.safeTransferFrom(user2, user3, tokenId, { from: user2 })
      expectEvent(receipt, 'Transfer', { from: user2, to: user3, tokenId })
      expect(await this.staker.balanceOf(user2)).to.be.bignumber.equal(new BN('0'))
      expect(await this.staker.balanceOf(user3)).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.ownerOf(tokenId)).to.equal(user3)
    })
    it('allows creation of another stake', async () => {
      const stakeAmount = hexTokens('20000')
      await this.hex.mint(user2, stakeAmount, { from: admin })
      await this.hex.approve(this.staker.address, MAX_UINT256, { from: user2 })
      await this.staker.createStake(stakeAmount, 20, this.fee, { from: user2 })
      const tokenId = new BN('2')
      const stakeIndex = new BN('1')
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      expect(await this.staker.totalSupply()).to.be.bignumber.equal(new BN('2'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('3'))
    })
    it('reorders indices when closing a stake', async () => {
      await this.staker.unstake(new BN('1'), { from: user3 })
      const tokenId = new BN('2')
      const stakeIndex = new BN('0')
      // verify other open stake data
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      // verify global properties
      expect(await this.staker.totalSupply()).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('3'))
    })
    it('only allows owner to open fee-less stake', async () => {
      await expectRevert(
        this.staker.directStakeTo(user1, hexTokens('2000'), 2, { from: user1 }),
        'Ownable: caller is not the owner'
      )

      const stakeAmount = hexTokens('100000')
      await this.hex.mint(admin, stakeAmount, { from: admin })
      await this.hex.approve(this.staker.address, stakeAmount, { from: admin })
      const receipt = await this.staker.directStakeTo(admin, stakeAmount, 100, { from: admin })
      const tokenId = new BN('3')
      expectEvent(receipt, 'Transfer', { from: ZERO_ADDRESS, to: admin, tokenId })
      const res = expectEvent.notEmitted(receipt, 'AccountedFee')
      const stakeIndex = new BN('1')
    })
  })
})
