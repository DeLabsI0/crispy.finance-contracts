const { BN } = require('bn.js')

const ZERO = new BN('0')
const bnSum = (...nums) => nums.reduce((x, y) => x.add(y), ZERO)
const encodeFunctionCall = (contract, method, args) => {
  const data = contract.contract.methods[method](...args).encodeABI()
  console.log('data: ', data)
}

module.exports = { ZERO, bnSum, encodeFunctionCall }
