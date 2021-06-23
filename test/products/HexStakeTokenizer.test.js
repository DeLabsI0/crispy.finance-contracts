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
  describe('normal single stake creation and use', () => {
    it('disallows stake creation if fee changed', async () => {
      const feePreChange = this.fee
      this.fee = this.fee.mul(new BN('2'))
      await this.staker.setFee(this.fee, { from: admin })
      await expectRevert(
        this.staker.createStakeFor(user1, ether('20'), 20, feePreChange, { from: user1 }),
        'FeeTaker: fee too high'
      )
    })
    it('disallows stake creation if user does not have sufficient funds', async () => {
      await expectRevert(
        this.staker.createStakeFor(user1, ether('20'), 20, this.fee, { from: user1 }),
        'ERC20: transfer amount exceeds balance'
      )
    })
    it('disallows stake creation if user did not approve staker contract', async () => {
      this.stakeAmount = hexTokens('6000')
      await this.hex.mint(user1, this.stakeAmount, { from: admin })
      await expectRevert(
        this.staker.createStakeFor(user1, this.stakeAmount, 20, this.fee, { from: user1 }),
        'ERC20: transfer amount exceeds allowance'
      )
    })
    it('allows user to create stake', async () => {
      await this.hex.approve(this.staker.address, MAX_UINT256, { from: user1 })
      const receipt = await this.staker.createStakeFor(user1, this.stakeAmount, 20, this.fee, {
        from: user1
      })
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
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(
        stakeId,
        'Wrong stakeId stored in staker'
      )
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('1'))
    })
    it('only allows stake owner to unstake', async () => {
      const tokenId = new BN('0')
      await expectRevert(
        this.staker.unstakeTo(attacker, tokenId, { from: attacker }),
        'CHXS: Caller not approved'
      )
      const balTracker = await trackBalance(this.hex, user1)
      const { stakeShares: stakeYield } = await this.hex.stakeLists(
        this.staker.address,
        new BN('0')
      )
      const receipt = await this.staker.unstakeTo(user1, tokenId, { from: user1 })
      expectEvent(receipt, 'Transfer', {
        from: user1,
        to: ZERO_ADDRESS,
        tokenId
      })
      expect(await this.staker.balanceOf(user1)).to.be.bignumber.equal(new BN('0'))
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(new BN('0'))
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
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(new BN('1'))
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
      await this.staker.createStakeFor(user2, stakeAmount, 20, this.fee, { from: user2 })
      const tokenId = new BN('2')
      const stakeIndex = new BN('1')
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(new BN('2'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('3'))
    })
    it('reorders indices when closing a stake', async () => {
      await this.staker.unstakeTo(user3, new BN('1'), { from: user3 })
      const tokenId = new BN('2')
      const stakeIndex = new BN('0')
      // verify other open stake data
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      // verify global properties
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('3'))
    })
  })
  describe('manual unstake', () => {
    before(async () => {
      const stakeAmount = hexTokens('2000')
      await this.hex.mint(user1, stakeAmount, { from: admin })
      await this.staker.createStakeFor(user1, stakeAmount, 30, this.fee, { from: user1 })
    })
    it('disallows non-owner from manually unstaking', async () => {
      const tokenId = new BN('2')
      const stakeIndex = new BN('0')
      await expectRevert(
        this.staker.manuallyUnstakeTo(attacker, tokenId, stakeIndex, { from: attacker }),
        'CHXS: Caller not approved'
      )
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(new BN('2'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('4'))
    })
    it('only allows manual unstake with valid index', async () => {
      const tokenId = new BN('2')
      const stakeIndex = new BN('0')
      const wrongStakeIndex = new BN('1')
      await expectRevert(
        this.staker.manuallyUnstakeTo(user2, tokenId, wrongStakeIndex, { from: user2 }),
        'CHXS: Invalid stake index'
      )
      const { stakeShares: stakeYield } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      const balTracker = await trackBalance(this.hex, user3)
      await this.staker.manuallyUnstakeTo(user3, tokenId, stakeIndex, { from: user2 })
      expect(await balTracker.delta()).to.be.bignumber.equal(stakeYield)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(new BN('1'))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(new BN('4'))

      const reorderedTokenId = new BN('3')
      const reorderedStakeIndex = new BN('0')
      expect(await this.staker.getTokenId(reorderedStakeIndex)).to.be.bignumber.equal(
        reorderedTokenId
      )
      expect(await this.staker.getStakeIndex(reorderedTokenId)).to.be.bignumber.equal(
        reorderedStakeIndex
      )
    })
  })
  describe('multiple stake creation and redemption', () => {
    before(async () => {
      await this.staker.unstakeTo(user1, new BN('3'), { from: user1 })
    })
    it('allows creation of multiple stakes', async () => {
      const totalStakeAmount = hexTokens('120000')
      await this.hex.mint(user1, totalStakeAmount, { from: admin })
      let afterFeeStakeAmount = totalStakeAmount.sub(totalStakeAmount.mul(this.fee).div(this.scale))
      const stake3Amount = afterFeeStakeAmount.div(new BN('6'))
      afterFeeStakeAmount = afterFeeStakeAmount.sub(stake3Amount)
      const stake2Amount = afterFeeStakeAmount.mul(new BN('2')).div(new BN('5'))
      const stake1Amount = afterFeeStakeAmount.sub(stake2Amount)

      const balTracker = await trackBalance(this.hex, user1)
      await this.staker.createStakesFor(
        user2,
        [stake1Amount, stake2Amount, stake3Amount],
        [10, 20, 30],
        this.fee,
        totalStakeAmount,
        { from: user1 }
      )
      expect(await balTracker.delta()).to.be.bignumber.equal(totalStakeAmount.neg())
      for (let i = 0; i < 3; i++) {
        const tokenId = i + 4
        expect(await this.staker.ownerOf(tokenId)).to.equal(user2)
        expect(await this.staker.getTokenId(i)).to.be.bignumber.equal(new BN(tokenId))
        expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(new BN(i))
      }
    })
    it('only allows owner to unstake multiple stakes', async () => {
      await expectRevert(
        this.staker.unstakeManyTo(attacker, [new BN('4'), new BN('5')], { from: attacker }),
        'CHXS: Caller not approved'
      )
      const { stakeShares: stakeYield1 } = await this.hex.stakeLists(this.staker.address, 0)
      const { stakeShares: stakeYield2 } = await this.hex.stakeLists(this.staker.address, 1)
      const balTracker = await trackBalance(this.hex, user3)
      await this.staker.unstakeManyTo(user3, [4, 5], { from: user2 })
      expect(await balTracker.delta()).to.be.bignumber.equal(stakeYield1.add(stakeYield2))

      const tokenId = new BN('6')
      const stakeIndex = new BN('0')
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
    })
    it('prevents creation if fee changed', async () => {
      const totalDeposit = hexTokens('10000')
      const stakeAmount = totalDeposit.sub(totalDeposit.mul(this.fee).div(this.scale))
      await this.staker.setFee(this.fee.mul(new BN('2')), { from: admin })
      await expectRevert(
        this.staker.createStakesFor(user1, [stakeAmount], [20], this.fee, totalDeposit, {
          from: user1
        }),

        'FeeTaker: fee too high'
      )
      await this.staker.setFee(this.fee, { from: admin })
    })
    it('refunds rest if fee is reduced', async () => {
      const origFee = ether('0.5')
      this.fee = ether('0.2')
      await this.staker.setFee(this.fee, { from: admin })
      const stakeAmount = hexTokens('10000')
      const upfrontTotal = stakeAmount.mul(this.scale).div(this.scale.sub(origFee))
      await this.hex.mint(user1, upfrontTotal, { from: admin })
      const balTracker = await trackBalance(this.hex, user1)
      await this.staker.createStakesFor(user1, [stakeAmount], [20], origFee, upfrontTotal, {
        from: user1
      })
      const actualFee = stakeAmount.mul(this.fee).div(this.scale.sub(this.fee))
      const actualDeduction = stakeAmount.add(actualFee)
      expect(await balTracker.delta()).to.be.bignumber.equal(actualDeduction.neg())
    })
  })
  describe('gas usage', () => {})
})
