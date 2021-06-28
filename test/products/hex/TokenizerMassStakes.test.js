const { accounts, contract } = require('@openzeppelin/test-environment')
const { constants } = require('@openzeppelin/test-helpers')
const { MAX_UINT256 } = constants
const { ZERO, safeBN, ether } = require('../../utils/general.js')
const seedrandom = require('seedrandom')
const [admin, user] = accounts
const { expect } = require('chai')

const MAIN_PROB = 0.8 // probability of doing main action (closing / opening stake)
const EXTEND_PROB = 0.1
const TOTAL_STAKES = 150

const HexStakeTokenizer = contract.fromArtifact('HexStakeTokenizer')
const HexMock = contract.fromArtifact('HexMock')

const hexTokens = (amount) => ether(amount, 'gwei').div(safeBN(10))

describe('HexStakeTokenizer multi stake creation and ending simulation', () => {
  before(async () => {
    this.hex = await HexMock.new({ from: admin })
    this.fee = ZERO
    this.staker = await HexStakeTokenizer.new(this.fee, this.hex.address, { from: admin })
    this.staker.totalTokensIssued = 0
    this.staker.getTokenStakeId = async (tokenId) => {
      const stakeIndex = await this.staker.getStakeIndex(tokenId)
      const { stakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      return stakeId
    }
    this.staker.openStakes = []
    this.staker.scale = await this.staker.SCALE()
    this.staker.tokenToStakeId = {}

    await this.hex.mint(user, hexTokens('1000000000'), { from: admin })
    await this.hex.approve(this.staker.address, MAX_UINT256, { from: user })

    const seed = Math.floor(Math.random() * 1e6)
    // const seed = 246507
    console.log('seed: ', seed)
    this.random = seedrandom(seed)
    this.rangeRandom = (start, end) => Math.floor(this.random() * (end - start)) + start

    this.openStake = async () => {
      await this.staker.createStakeFor(
        user,
        hexTokens(this.rangeRandom(1000, 8000)),
        this.rangeRandom(20, 200),
        this.fee,
        { from: user }
      )
      const tokenId = this.staker.totalTokensIssued++
      const stakeIndex = this.staker.openStakes.length
      const stakeId = await this.staker.getTokenStakeId(tokenId)
      const { stakeId: directStakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(stakeId).to.be.bignumber.equal(directStakeId)
      this.staker.openStakes.push(tokenId)
      this.staker.tokenToStakeId[tokenId] = stakeId
    }

    this.closeStake = async () => {
      const randomIndex = this.rangeRandom(0, this.staker.openStakes.length)
      const stakeToClose = this.staker.openStakes[randomIndex]
      const stakeId = await this.staker.getTokenStakeId(stakeToClose)
      expect(stakeId).to.be.bignumber.equal(this.staker.tokenToStakeId[stakeToClose])
      await this.staker.unstakeTo(user, stakeToClose, { from: user })
      this.staker.openStakes = this.staker.openStakes.filter((stake) => stake !== stakeToClose)
    }

    this.extendStake = async () => {
      const randomIndex = this.rangeRandom(0, this.staker.openStakes.length)
      const stakeToExtend = this.staker.openStakes[randomIndex]
      const stakeId = await this.staker.getTokenStakeId(stakeToExtend)
      expect(stakeId).to.be.bignumber.equal(this.staker.tokenToStakeId[stakeToExtend], 'exc1')
      await this.staker.extendStakeLength(
        stakeToExtend,
        this.rangeRandom(20, 200),
        hexTokens(this.rangeRandom(1000, 8000)),
        this.fee,
        { from: user }
      )
      const newStakeId = await this.staker.getTokenStakeId(stakeToExtend)
      const stakeIndex = this.staker.openStakes.length - 1
      const { stakeId: directStakeId } = await this.hex.stakeLists(this.staker.address, stakeIndex)
      expect(newStakeId).to.be.bignumber.equal(directStakeId, 'exc2')
      this.staker.openStakes[randomIndex] = stakeToExtend
      this.staker.tokenToStakeId[stakeToExtend] = newStakeId
    }
  })
  it('opens stakes', async () => {
    while (this.staker.openStakes.length < TOTAL_STAKES) {
      const len = this.staker.openStakes.length
      if (len !== 0 && len % 10 === 0) {
        console.log('len: ', len)
      }
      const rand = this.random()
      if (len === 0 || rand <= MAIN_PROB) {
        await this.openStake()
      } else if (rand <= MAIN_PROB + EXTEND_PROB) {
        await this.extendStake()
      } else {
        await this.closeStake()
      }
    }
  })
  it('closes stakes', async () => {
    while (this.staker.openStakes.length > 0) {
      const len = this.staker.openStakes.length
      if (len !== 0 && len % 10 === 0) {
        console.log('len: ', len)
      }
      const rand = this.random()
      if (len === 0 || rand <= MAIN_PROB) {
        await this.closeStake()
      } else if (rand <= MAIN_PROB + EXTEND_PROB) {
        await this.extendStake()
      } else {
        await this.openStake()
      }
    }
  })
})
