/*

const { accounts, contract } = require('@openzeppelin/test-environment')
const {
  expectEvent,
  constants: { ZERO_ADDRESS }
} = require('@openzeppelin/test-helpers')
const { bnToWei, ZERO, bnSum } = require('./utils')
const { BN } = require('bn.js')
const [admin1, user1, user2, delegate1, delegate2] = accounts

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

  describe('voting snapshotting', () => {
    it('saves total vote weight', async () => {
      const snapshotIds = []

      const takeSnapshot = async () => {
        const {
          logs: [snapShotLog]
        } = await this.crispyToken.snapshot({ from: admin1 })
        expect(snapShotLog.event).to.equal('VoteWeightsSnapshot')

        snapshotIds.push(snapShotLog.args.id)
      }

      await takeSnapshot()

      const mintAmount1 = bnToWei('12000')
      await this.crispyToken.mint(user1, mintAmount1, { from: admin1 })

      await takeSnapshot()

      const burnAmount1 = bnToWei('1000')
      await this.crispyToken.burn(burnAmount1, { from: user1 })

      await takeSnapshot()

      expect(await this.crispyToken.totalVoteWeightAt(snapshotIds[0])).to.be.bignumber.equal(ZERO)
      expect(await this.crispyToken.totalVoteWeightAt(snapshotIds[1])).to.be.bignumber.equal(
        mintAmount1
      )
      expect(await this.crispyToken.totalVoteWeightAt(snapshotIds[2])).to.be.bignumber.equal(
        mintAmount1.sub(burnAmount1)
      )
    })
  })

  describe('voting delegation', () => {
    beforeEach(async () => {})

    it('transfers and creates vote weight with balance', async () => {
      expect(await this.crispyToken.voteWeightOf(user1)).to.be.bignumber.equal(
        ZERO,
        'default vote weight should be 0'
      )

      const user1StartBal = bnToWei('1200')
      let txReceipt

      txReceipt = expectEvent(
        await this.crispyToken.mint(user1, user1StartBal, { from: admin1 }),
        'VoteWeightChanged',
        {
          delegate: user1,
          fromVoteWeight: ZERO,
          toVoteWeight: user1StartBal
        }
      )

      expect(await this.crispyToken.balanceOf(user1)).to.be.bignumber.equal(user1StartBal)
      expect(await this.crispyToken.voteWeightOf(user1)).to.be.bignumber.equal(
        user1StartBal,
        'vote weight is expected to equal balance without delegation'
      )

      txReceipt = await this.crispyToken.delegateVoteWeightTo(delegate1, { from: user1 })
      expectEvent(txReceipt, 'DelegateChanged', {
        delegator: user1,
        fromDelegate: ZERO_ADDRESS,
        toDelegate: delegate1
      })
      expectEvent(txReceipt, 'VoteWeightChanged', {
        delegate: user1,
        fromVoteWeight: user1StartBal,
        toVoteWeight: ZERO
      })
      expectEvent(txReceipt, 'VoteWeightChanged', {
        delegate: delegate1,
        fromVoteWeight: ZERO,
        toVoteWeight: user1StartBal
      })

      const furtherMintAmount = bnToWei('800')
      await this.crispyToken.mint(user1, furtherMintAmount, { from: admin1 })
      expect(await this.crispyToken.balanceOf(user1)).to.be.bignumber.equal(
        user1StartBal.add(furtherMintAmount)
      )
      expect(await this.crispyToken.voteWeightOf(user1)).to.be.bignumber.equal(
        ZERO,
        'Users direct vote weight is expected to be zero since it was delegated'
      )
      expect(await this.crispyToken.voteWeightOf(delegate1)).to.be.bignumber.equal(
        user1StartBal.add(furtherMintAmount),
        'Delegate is expcted to receive vote weight from users balance'
      )

      const delegateMintAmount = bnToWei('500')
      const expectedTotal = bnSum(user1StartBal, furtherMintAmount, delegateMintAmount)
      expectEvent(
        await this.crispyToken.mint(delegate1, delegateMintAmount, { from: admin1 }),

        'VoteWeightChanged',
        {
          delegate: delegate1,
          fromVoteWeight: bnSum(user1StartBal, furtherMintAmount),
          toVoteWeight: expectedTotal
        }
      )
      expect(await this.crispyToken.voteWeightOf(delegate1)).to.be.bignumber.equal(expectedTotal)

      const transferAmount = bnToWei('100')
      txReceipt = await this.crispyToken.transfer(user2, transferAmount, { from: user1 })
      expectEvent(txReceipt, 'VoteWeightChanged', {
        delegate: user2,
        fromVoteWeight: ZERO,
        toVoteWeight: transferAmount
      })
      expectEvent(txReceipt, 'VoteWeightChanged', {
        delegate: delegate1,
        fromVoteWeight: bnSum(user1StartBal, furtherMintAmount, delegateMintAmount),
        toVoteWeight: expectedTotal.sub(transferAmount)
      })
    })

    it('returns vote weight when changing delegate', async () => {
      const totalMintAmount = bnToWei('800')
      await this.crispyToken.mint(user1, totalMintAmount, { from: admin1 })

      expect(await this.crispyToken.voteWeightOf(user1)).to.be.bignumber.equal(totalMintAmount)

      let txReceipt
      await this.crispyToken.delegateVoteWeightTo(delegate1, { from: user1 })
      expect(await this.crispyToken.voteWeightOf(user1)).to.be.bignumber.equal(ZERO)
      expect(await this.crispyToken.voteWeightOf(delegate1)).to.be.bignumber.equal(totalMintAmount)

      txReceipt = await this.crispyToken.delegateVoteWeightTo(delegate2, { from: user1 })
      expect(await this.crispyToken.voteWeightOf(user1)).to.be.bignumber.equal(ZERO)
      expect(await this.crispyToken.voteWeightOf(delegate1)).to.be.bignumber.equal(ZERO)
      expect(await this.crispyToken.voteWeightOf(delegate2)).to.be.bignumber.equal(totalMintAmount)

      expectEvent(txReceipt, 'VoteWeightChanged', {
        delegate: delegate1,
        fromVoteWeight: totalMintAmount,
        toVoteWeight: ZERO
      })

      expectEvent(txReceipt, 'VoteWeightChanged', {
        delegate: delegate2,
        fromVoteWeight: ZERO,
        toVoteWeight: totalMintAmount
      })
    })
  })
})

*/
