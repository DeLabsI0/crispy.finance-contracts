const BN = require('bn.js')

const VERSION = '0.1.0'

const fracMul = async (governor, x, y) => {
  return x.mul(y).div(await governor.ONE())
}

const getTotalTax = async (governor) => {
  const activationThreshhold = await governor.activationThreshhold()
  const taxRate = await governor.ACTIVATION_TAX()

  return await fracMul(governor, activationThreshhold, taxRate)
}

const getFutureFinishReward = async (governor) => {
  const totalTax = await getTotalTax(governor)
  const finishRewardShare = await governor.FINISH_REWARD()

  return await fracMul(governor, totalTax, finishRewardShare)
}

const getTax = async (governor) => {
  const totalTax = await getTotalTax(governor)
  const finishReward = await getFutureFinishReward(governor)

  return totalTax.sub(finishReward)
}

const lockForVote = async (governor, crispyToken, account) => {
  if (await governor.finished()) throw new Error('No ongoing vote')
  const lockUntil = (await governor.voteEnd()).add(new BN('1'))
  await crispyToken.lockBalanceUntil(lockUntil, { from: account })
}

const VOTE_FOR = new BN('1')
const VOTE_AGAINST = new BN('2')

module.exports = {
  VERSION,

  VOTE_FOR,
  VOTE_AGAINST,
  fracMul,
  lockForVote,
  getTotalTax,
  getFutureFinishReward,
  getTax
}
