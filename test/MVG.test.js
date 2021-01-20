const { accounts, contract, web3 } = require('@openzeppelin/test-environment')
const { expectEvent, constants, send } = require('@openzeppelin/test-helpers')
const { MAX_UINT256 } = constants
const governance = require('./utils/crispy/governance')
const {
  bnPerc,
  getTxNonce,
  getDetAddr,
  trackBalance,
  ether,
  encodeFunctionCall,
  ZERO
} = require('./utils/general')
const { decodeAllLogs } = require('./utils/events')
const { BN } = require('bn.js')
const [admin1, admin2, user1, user2, user3, user4, attacker1] = accounts

const chai = require('chai')
chai.use(require('chai-bn')(BN))
const { expect } = chai

const MVG = contract.fromArtifact('MVG')
const Treasury = contract.fromArtifact('Treasury')
const CrispyToken = contract.fromArtifact('CrispyToken')
const DoneChecker = contract.fromArtifact('DoneChecker')

describe('MVG', () => {
  beforeEach(async () => {
    this.treasury = await Treasury.new({ from: admin1 })
    this.crispyToken = await CrispyToken.new({ from: admin1 })

    const HARD_CAP = await this.crispyToken.HARD_CAP()

    const allocations = [
      // real allocations
      { addr: this.treasury.address, perc: '30' },
      { addr: admin1, perc: '18' },

      // test allocations
      { addr: admin2, perc: '13' },
      { addr: user1, perc: '13' },
      { addr: user2, perc: '13' },
      { addr: user3, perc: '13' }
    ]

    await Promise.all(
      allocations.map(({ addr, perc }) => {
        const allocation = bnPerc(HARD_CAP, perc)
        return this.crispyToken.mint(addr, allocation, { from: admin1 })
      })
    )
    expect(await this.crispyToken.totalSupply()).to.be.bignumber.equal(HARD_CAP)
    const receipt = await this.crispyToken.transferOwnership(this.treasury.address, {
      from: admin1
    })
    const nonce = await getTxNonce(receipt.tx)
    const governorAddr = await getDetAddr(admin1, nonce + 2)

    await this.treasury.transferOwnership(governorAddr, { from: admin1 })

    this.governor = await MVG.new(this.crispyToken.address, this.treasury.address, { from: admin1 })
    expect(this.governor.address).to.equal(governorAddr)

    await send.ether(admin1, this.treasury.address, ether('2'))
  })
  describe('deploy conditions', () => {
    it('has correct owner chain', async () => {
      expect(await this.crispyToken.owner()).to.equal(this.treasury.address)
      expect(await this.treasury.owner()).to.equal(this.governor.address)
    })
    it('starts in finished state', async () => {
      expect(await this.governor.finished()).to.be.true
    })
  })
  describe('voting mechanism', () => {
    it('allows creation and execution of action', async () => {
      const user1BalTracker = await trackBalance(this.crispyToken, user1)

      await this.crispyToken.approve(this.governor.address, MAX_UINT256, { from: user1 })

      const callData = encodeFunctionCall(this.treasury, 'callDirect', [user4, ether('1'), '0x'])
      const callDataHash = web3.utils.soliditySha3(callData)

      const totalTax = await governance.getTotalTax(this.governor)
      const tax = await governance.getTax(this.governor)
      const finishReward = await governance.getFutureFinishReward(this.governor)
      const expectedActionNonce = new BN('1')

      const treasuryCReserves = await trackBalance(this.crispyToken, this.treasury.address)
      let receipt = await this.governor.initiateAction(callData, { from: user1 })

      const block = await web3.eth.getBlock(receipt.receipt.blockNumber)
      const timestamp = new BN(block.timestamp)

      expectEvent(receipt, 'ActionInitiated', {
        callDataHash,
        actionNonce: expectedActionNonce,
        activatedOn: timestamp,
        votingEndsOn: timestamp.add(await this.governor.VOTE_PERIOD()),
        callData
      })
      expectEvent.inTransaction(receipt.tx, this.crispyToken, 'Transfer', {
        from: user1,
        to: this.treasury.address,
        value: tax
      })
      expectEvent.inTransaction(receipt.tx, this.crispyToken, 'Transfer', {
        from: user1,
        to: this.governor.address,
        value: finishReward
      })
      expect(await user1BalTracker.delta()).to.be.bignumber.equal(
        totalTax.neg(),
        'Incorrect tax deducted'
      )
      expect(await treasuryCReserves.delta()).to.be.bignumber.equal(
        tax,
        'Treasury was not awarded tax'
      )
      expect(await this.governor.finishReward()).to.be.bignumber.equal(
        finishReward,
        'Incorrect finish reward stored'
      )
      expect(await this.governor.finished(), 'Action should not be finished').to.be.false
      expect(await this.governor.callData()).to.equal(callData, 'Incorrect call data')

      const doneChecker = await DoneChecker.new(this.governor.address, { from: user1 })
      expectEvent(await doneChecker.checkDone(), 'Result', { value: false })

      expect(
        await this.governor.voteCount(governance.VOTE_FOR),
        'Votes are expected to start at 0'
      ).to.be.bignumber.equal(ZERO)
      expect(
        await this.governor.voteCount(governance.VOTE_AGAINST),
        'Votes are expected to start at 0'
      ).to.be.bignumber.equal(ZERO)

      await governance.lockForVote(this.governor, this.crispyToken, user1)
      const user1Bal = await user1BalTracker.get()
      receipt = await this.governor.vote(governance.VOTE_FOR, { from: user1 })
      expectEvent(receipt, 'VoteChanged', {
        account: user1,
        callDataHash,
        actionNonce: expectedActionNonce,
        vote: governance.VOTE_FOR,
        voteCountBefore: ZERO,
        voteCountAfter: user1Bal
      })
      expect(receipt.logs.length).to.equal(1, 'Incorrect additional logs')

      expect(await this.governor.voteCount(governance.VOTE_AGAINST)).to.be.bignumber.equal(ZERO)
      expect(await this.governor.voteCount(governance.VOTE_FOR)).to.be.bignumber.equal(user1Bal)

      const treasuryEReserves = await trackBalance(null, this.treasury.address)
    })
  })
})
