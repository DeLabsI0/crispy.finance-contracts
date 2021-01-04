const { BN } = require('bn.js')
const { web3 } = require('@openzeppelin/test-environment')

const ZERO = new BN('0')
const bnToWei = (x) => new BN(web3.utils.toWei(x))
const bnSum = (...nums) => nums.reduce((x, y) => x.add(y), ZERO)

module.exports = { ZERO, bnToWei, bnSum }
