const { accounts, contract } = require('@openzeppelin/test-environment')
const { expectRevert, expectEvent, constants } = require('@openzeppelin/test-helpers')
const { MAX_UINT256, ZERO_ADDRESS } = constants
const { ether, trackBalance, safeBN, ZERO } = require('../utils/general')
const [admin, attacker, user1, user2, user3] = accounts
const { expect } = require('chai')

const HexStakeTokenizer = contract.fromArtifact('HexStakeTokenizer')
const HexMock = contract.fromArtifact('HexMock')

describe('HexStakeTokenizer', () => {
  const hexTokens = (amount) => ether(amount, 'gwei').div(safeBN(10))
  before(async () => {
    this.hex = await HexMock.new({ from: admin })
    this.fee = ether('0.01')
    this.staker = await HexStakeTokenizer.new(this.fee, this.hex.address, { from: admin })
    this.scale = await this.staker.SCALE()
  })
  describe('owner functionality', () => {
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
      this.fee = this.fee.mul(safeBN(2))
      await this.staker.setFee(this.fee, { from: admin })
      await expectRevert(
        this.staker.createStakeFor(user1, ether('20'), 20, feePreChange, { from: user1 }),
        'FeeTaker: Fee too high'
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
      const tokenId = safeBN(0)
      expectEvent(receipt, 'Transfer', {
        from: ZERO_ADDRESS,
        to: user1,
        tokenId
      })
      expectEvent(receipt, 'AccountedFee', {
        token: this.hex.address,
        amount: this.stakeAmount.mul(this.fee).div(this.scale)
      })
      expect(await this.staker.balanceOf(user1)).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.ownerOf(tokenId)).to.equal(user1)
      expect(await this.hex.stakeCount(this.staker.address)).to.be.bignumber.equal(safeBN(1))
      const stakeIndex = safeBN(0)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(
        stakeId,
        'Wrong stakeId stored in staker'
      )
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(1))
    })
    it('only allows stake owner to unstake', async () => {
      const tokenId = safeBN(0)
      await expectRevert(
        this.staker.unstakeTo(attacker, tokenId, { from: attacker }),
        'CHXS: Caller not approved'
      )
      const balTracker = await trackBalance(this.hex, user1)
      const { stakeShares: stakeYield } = await this.hex.stakeLists(this.staker.address, safeBN(0))
      const receipt = await this.staker.unstakeTo(user1, tokenId, { from: user1 })
      expectEvent(receipt, 'Transfer', { from: user1, to: ZERO_ADDRESS, tokenId })
      expect(await this.staker.balanceOf(user1)).to.be.bignumber.equal(safeBN(0))
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(0))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(1))
      expect(await balTracker.delta()).to.be.bignumber.equal(stakeYield)
      expect(await this.hex.stakeCount(this.staker.address)).to.be.bignumber.equal(safeBN(0))
    })
    it('allows user to create a stake for another address', async () => {
      const stakeAmount = hexTokens('1000')
      await this.hex.mint(user1, stakeAmount, { from: admin })
      const receipt = await this.staker.createStakeFor(user2, stakeAmount, 20, this.fee, {
        from: user1
      })
      const tokenId = safeBN(1)
      expectEvent(receipt, 'Transfer', { from: ZERO_ADDRESS, to: user2, tokenId })
      expect(await this.staker.balanceOf(user2)).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.ownerOf(tokenId)).to.equal(user2)
      const stakeIndex = safeBN(0)
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(2))
    })
    it('allows transfer of stake', async () => {
      const tokenId = safeBN(1)
      const receipt = await this.staker.safeTransferFrom(user2, user3, tokenId, { from: user2 })
      expectEvent(receipt, 'Transfer', { from: user2, to: user3, tokenId })
      expect(await this.staker.balanceOf(user2)).to.be.bignumber.equal(safeBN(0))
      expect(await this.staker.balanceOf(user3)).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.ownerOf(tokenId)).to.equal(user3)
    })
    it('allows creation of another stake', async () => {
      const stakeAmount = hexTokens('20000')
      await this.hex.mint(user2, stakeAmount, { from: admin })
      await this.hex.approve(this.staker.address, MAX_UINT256, { from: user2 })
      await this.staker.createStakeFor(user2, stakeAmount, 20, this.fee, { from: user2 })
      const tokenId = safeBN(2)
      const stakeIndex = safeBN(1)
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(2))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(3))
    })
    it('reorders indices when closing a stake', async () => {
      await this.staker.unstakeTo(user3, safeBN(1), { from: user3 })
      const tokenId = safeBN(2)
      const stakeIndex = safeBN(0)
      // verify other open stake data
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
      // verify global properties
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(3))
    })
  })
  describe('manual unstake', () => {
    before(async () => {
      const stakeAmount = hexTokens('2000')
      await this.hex.mint(user1, stakeAmount, { from: admin })
      await this.staker.createStakeFor(user1, stakeAmount, 30, this.fee, { from: user1 })
    })
    it('disallows non-owner from manually unstaking', async () => {
      const tokenId = safeBN(2)
      const stakeIndex = safeBN(0)
      await expectRevert(
        this.staker.manuallyUnstakeTo(attacker, tokenId, stakeIndex, { from: attacker }),
        'CHXS: Caller not approved'
      )
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(2))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(4))
    })
    it('only allows manual unstake with valid index', async () => {
      const tokenId = safeBN(2)
      const stakeIndex = safeBN(0)
      const wrongStakeIndex = safeBN(1)
      await expectRevert(
        this.staker.manuallyUnstakeTo(user2, tokenId, wrongStakeIndex, { from: user2 }),
        'CHXS: Invalid stake index'
      )
      const { stakeShares: stakeYield } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      const balTracker = await trackBalance(this.hex, user3)
      await this.staker.manuallyUnstakeTo(user3, tokenId, stakeIndex, { from: user2 })
      expect(await balTracker.delta()).to.be.bignumber.equal(stakeYield)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(4))

      const reorderedTokenId = safeBN(3)
      const reorderedStakeIndex = safeBN(0)
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
      // reude open stakes to zero
      await this.staker.unstakeTo(user1, safeBN(3), { from: user1 })
    })
    it('allows creation of multiple stakes', async () => {
      const totalStakeAmount = hexTokens('120000')
      await this.hex.mint(user1, totalStakeAmount, { from: admin })
      let afterFeeStakeAmount = totalStakeAmount.sub(totalStakeAmount.mul(this.fee).div(this.scale))
      const stake3Amount = afterFeeStakeAmount.div(safeBN(6))
      afterFeeStakeAmount = afterFeeStakeAmount.sub(stake3Amount)
      const stake2Amount = afterFeeStakeAmount.mul(safeBN(2)).div(safeBN(5))
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
        expect(await this.staker.getTokenId(i)).to.be.bignumber.equal(safeBN(tokenId))
        expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(safeBN(i))
      }
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(3))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(7))
    })
    it('only allows owner to unstake multiple stakes', async () => {
      await expectRevert(
        this.staker.unstakeManyTo(attacker, [safeBN(4), safeBN(5)], { from: attacker }),
        'CHXS: Caller not approved'
      )
      const { stakeShares: stakeYield1 } = await this.hex.stakeLists(this.staker.address, 0)
      const { stakeShares: stakeYield2 } = await this.hex.stakeLists(this.staker.address, 1)
      const balTracker = await trackBalance(this.hex, user3)
      await this.staker.unstakeManyTo(user3, [4, 5], { from: user2 })
      expect(await balTracker.delta()).to.be.bignumber.equal(stakeYield1.add(stakeYield2))

      const tokenId = safeBN(6)
      const stakeIndex = safeBN(0)
      expect(await this.staker.getTokenId(stakeIndex)).to.be.bignumber.equal(tokenId)
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(7))
    })
    it('prevents creation if fee changed', async () => {
      const totalDeposit = hexTokens('10000')
      const stakeAmount = totalDeposit.sub(totalDeposit.mul(this.fee).div(this.scale))
      await this.staker.setFee(this.fee.mul(safeBN(2)), { from: admin })
      await expectRevert(
        this.staker.createStakesFor(user1, [stakeAmount], [20], this.fee, totalDeposit, {
          from: user1
        }),
        'FeeTaker: Fee too high'
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
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(2))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(8))
    })
  })
  describe('stake length extension', () => {
    before(async () => {
      await this.staker.unstakeTo(user2, safeBN(6), { from: user2 })
      await this.staker.unstakeTo(user1, safeBN(7), { from: user1 })
      const stakeAmount = hexTokens('3000')
      await this.staker.createStakeFor(user1, stakeAmount, safeBN(10), this.fee, { from: user1 })
    })
    it('only owner to reinvest', async () => {
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(9))
      const tokenId = safeBN(8)
      await expectRevert(
        this.staker.extendStakeLength(tokenId, safeBN(1), this.fee, ZERO, { from: attacker }),
        'CHXS: Caller not approved'
      )
      const stakeIndex = safeBN(0)
      const { stakeShares: stakeYield } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      const fee = stakeYield.mul(this.fee).div(this.scale)
      const newStakeAmount = stakeYield.sub(fee)
      const newStakeDays = safeBN(20)
      const receipt = await this.staker.extendStakeLength(tokenId, newStakeDays, this.fee, ZERO, {
        from: user1
      })
      expectEvent(receipt, 'AccountedFee', { token: this.hex.address, amount: fee })
      expectEvent(receipt, 'ExtendStake', { tokenId })
      expectEvent.notEmitted(receipt, 'Transfer')
      expect(await this.staker.getStakeIndex(tokenId)).to.be.bignumber.equal(stakeIndex)
      const newStake = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(newStakeAmount).to.be.bignumber.equal(newStake.stakedHearts)
      expect(newStakeDays).to.be.bignumber.equal(newStake.stakedDays)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(newStake.stakeId)
      expect(await this.staker.totalOpenStakes()).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.totalIssuedTokens()).to.be.bignumber.equal(safeBN(9))
    })
    it('keeps track of stake indices', async () => {
      await this.staker.createStakeFor(user2, hexTokens('1000'), safeBN(20), this.fee, {
        from: user2
      })
      const tokenId1 = safeBN(8)
      const tokenId2 = safeBN(9)
      expect(await this.staker.ownerOf(tokenId2)).to.equal(user2)
      expect(await this.staker.getStakeIndex(tokenId1)).to.be.bignumber.equal(safeBN(0))
      expect(await this.staker.getStakeIndex(tokenId2)).to.be.bignumber.equal(safeBN(1))
      await this.staker.extendStakeLength(tokenId1, safeBN(20), this.fee, ZERO, {
        from: user1
      })
      expect(await this.staker.getStakeIndex(tokenId1)).to.be.bignumber.equal(safeBN(1))
      expect(await this.staker.getStakeIndex(tokenId2)).to.be.bignumber.equal(safeBN(0))
    })
    it('allows adding to stake', async () => {
      const tokenId = safeBN(8)
      const { stakeShares: stakeYield } = await this.hex.stakeLists(this.staker.address, safeBN(1))
      const addAmount = hexTokens('10000')
      const inputAmount = stakeYield.add(addAmount)
      const fee = inputAmount.mul(this.fee).div(this.scale)
      const stakeAmount = inputAmount.sub(fee)

      const receipt = await this.staker.extendStakeLength(
        tokenId,
        safeBN(30),
        this.fee,
        addAmount,
        { from: user1 }
      )
      expectEvent(receipt, 'ExtendStake', { tokenId })
      expectEvent(receipt, 'AccountedFee', { token: this.hex.address, amount: fee })
      const { stakedHearts, stakeId } = await this.hex.stakeLists(this.staker.address, safeBN(1))
      expect(stakeAmount).to.be.bignumber.equal(stakedHearts)
      expect(await this.staker.getTokenStakeId(tokenId)).to.be.bignumber.equal(stakeId)
    })
  })
  describe('external stake use', () => {
    it('allows approved user to unstake', async () => {
      const { stakeShares: stakeYield } = await this.hex.stakeLists(this.staker.address, safeBN(1))
      const tokenId = safeBN(8)
      expect(await this.staker.ownerOf(tokenId)).to.equal(user1)
      const balTracker = await trackBalance(this.hex, user3)
      await expectRevert(
        this.staker.unstakeTo(user3, tokenId, { from: user2 }),
        'CHXS: Caller not approved'
      )
      await this.staker.setApprovalForAll(user2, true, { from: user1 })
      await this.staker.unstakeTo(user3, tokenId, { from: user2 })
      expect(await balTracker.delta()).to.be.bignumber.equal(stakeYield)
    })
  })
  describe('gas usage', () => {})
})
