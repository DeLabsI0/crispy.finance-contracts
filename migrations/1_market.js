const Market = artifacts.require('Market')
const FaucetERC20 = artifacts.require('FaucetERC20')
const FaucetERC721 = artifacts.require('FaucetERC721')

module.exports = async (deployer, network) => {
  await deployer.deploy(Market)

  if (network === 'development' || network === 'testnet' || network === 'xdai') {
    await deployer.deploy(FaucetERC20, 'test faucet ERC20 token (valueless)')
    await deployer.deploy(FaucetERC721, 'test faucet ERC721 token (NFT, valueless)')
  }
}
