const { accounts, contract } = require('@openzeppelin/test-environment')
const { expectEvent, expectRevert, constants } = require('@openzeppelin/test-helpers')
const { ether, trackBalance, ZERO } = require('./utils/general')
const BN = require('bn.js')
const [admin, attacker, buyer1, buyer2, seller1, seller2] = accounts

const { expect } = require('chai')

const Market = contract.fromArtifact('Market')
const TestERC20 = contract.fromArtifact('TestERC20')
const TestERC721 = contract.fromArtifact('TestERC721')

describe('MVP Market', () => {
  before(async () => {
    this.token = await TestERC20.new('valueless test token', { from: admin })
    this.nft = await TestERC721.new('valueless test nft', { from: admin })
  })
  it('can deploy market', async () => {
    this.market = await Market.new({ from: admin })
    this.scale = await this.market.SCALE()
    this.toInverseFee = (fee) => this.scale.sub(fee)
    this.orderStatus = {
      BUY: new BN('0'),
      SELL: new BN('1'),
      FILLED: new BN('2'),
      CANCELLED: new BN('3')
    }
    expect(await this.market.totalOrders()).to.be.bignumber.equal(ZERO)
    expect(this.scale).to.be.bignumber.equal(ether('1'))
  })
  describe('management methods', () => {
    it('allows owner to set fee', async () => {
      this.fee = ether('0.0015') // 0.15%
      const receipt = await this.market.setFee(this.toInverseFee(this.fee), { from: admin })
      expectEvent(receipt, 'FeeSet', { newInverseFee: this.toInverseFee(this.fee) })
    })
    it('disallows non-owner from setting fee', async () => {
      await expectRevert(
        this.market.setFee(this.toInverseFee(ether('1.0')), { from: attacker }),
        'Ownable: caller is not the owner'
      )
    })
  })
  describe('order creation and filling', () => {
    before(async () => {
      await this.nft.mint(seller1, new BN('0'), { from: admin })
      await this.nft.mint(seller1, new BN('1'), { from: admin })
      await this.nft.mint(seller1, new BN('2'), { from: admin })

      await this.nft.mint(seller2, new BN('3'), { from: admin })
      await this.nft.mint(seller2, new BN('4'), { from: admin })

      await this.token.mint(buyer1, ether('50'), { from: admin })
      await this.token.mint(buyer2, ether('50'), { from: admin })

      this.sales = []
    })
    it('allows creation of public sell order', async () => {
      this.sales.push({
        amount: ether('8'),
        token: new BN('0'),
        orderId: new BN('0')
      })
      const receipt = await this.market.createOrder(
        true,
        constants.ZERO_ADDRESS,
        this.nft.address,
        this.sales[0].token,
        this.token.address,
        this.sales[0].amount,
        this.toInverseFee(this.fee),
        { from: seller1 }
      )

      expectEvent(receipt, 'OrderCreated', {
        orderId: this.sales[0].orderId,
        creator: seller1,
        permittedFiller: constants.ZERO_ADDRESS
      })

      const order = await this.market.orderBook(this.sales[0].orderId)
      expect(order.status).to.be.bignumber.equal(this.orderStatus.SELL)
      expect(order.creator).to.equal(seller1)
      expect(order.permittedFiller).to.equal(constants.ZERO_ADDRESS)
      expect(order.tokenContract).to.equal(this.nft.address)
      expect(order.tokenId).to.be.bignumber.equal(this.sales[0].token)
      expect(order.paymentToken).to.equal(this.token.address)
      expect(order.paymentAmount).to.be.bignumber.equal(this.sales[0].amount)
      expect(order.allowedInverseFee).to.be.bignumber.equal(this.toInverseFee(this.fee))
    })
    it('disallows non-creator from cancelling order', async () => {
      await expectRevert(
        this.market.cancelOrder(this.sales[0].orderId, { from: attacker }),
        'Market: unauthorized cancel'
      )
    })
    it('cannot fill order without necessary approvals', async () => {
      await expectRevert(
        this.market.fillOrder(this.sales[0].orderId, { from: buyer1 }),
        'ERC721: transfer caller is not owner nor approved'
      )
      await this.nft.setApprovalForAll(this.market.address, true, { from: seller1 })
      await expectRevert(
        this.market.fillOrder(this.sales[0].orderId, { from: buyer1 }),
        'ERC20: transfer amount exceeds allowance'
      )
      await this.token.approve(this.market.address, constants.MAX_UINT256, { from: buyer1 })
      await this.nft.setApprovalForAll(this.market.address, false, { from: seller1 })
      await expectRevert(
        this.market.fillOrder(this.sales[0].orderId, { from: buyer1 }),
        'ERC721: transfer caller is not owner nor approved'
      )
    })
    it('can fill order with necessary approvals', async () => {
      await this.nft.setApprovalForAll(this.market.address, true, { from: seller1 })

      const sellerTracker = await trackBalance(this.token, seller1)
      const buyerTracker = await trackBalance(this.token, buyer1)
      const marketTracker = await trackBalance(this.token, this.market.address)
      const receipt = await this.market.fillOrder(this.sales[0].orderId, { from: buyer1 })
      expectEvent(receipt, 'OrderFilled', {
        orderId: this.sales[0].orderId,
        filler: buyer1,
        usedInverseFee: this.toInverseFee(this.fee)
      })

      const saleAmount = this.sales[0].amount
      const afterFeeAmount = saleAmount.mul(this.toInverseFee(this.fee)).div(this.scale)
      const feeAmount = saleAmount.sub(afterFeeAmount)

      expect(await sellerTracker.delta()).to.be.bignumber.equal(afterFeeAmount)
      expect(await buyerTracker.delta()).to.be.bignumber.equal(saleAmount.neg())
      expect(await marketTracker.delta()).to.be.bignumber.equal(feeAmount)

      expect(await this.nft.ownerOf(this.sales[0].token)).to.equal(buyer1)
    })
    it('disallows filling of already filled order', async () => {
      await expectRevert(
        this.market.fillOrder(this.sales[0].orderId, { from: attacker }),
        'Market: order not fillable'
      )
    })
    it('disallows filling of non-existant order', async () => {
      const nonExistantOrderId = new BN('17')
      await expectRevert(
        this.market.fillOrder(nonExistantOrderId, { from: attacker }),
        'Market: non-existant order'
      )
    })
    it('allows cancellation of single order', async () => {
      await this.market.createOrder(
        true,
        constants.ZERO_ADDRESS,
        this.nft.address,
        new BN('1'),
        this.token.address,
        ether('8'),
        this.toInverseFee(this.fee),
        { from: seller1 }
      )
      this.cancelledOrderId = new BN('1')

      const receipt = await this.market.cancelOrder(this.cancelledOrderId, { from: seller1 })
      expectEvent(receipt, 'OrderCancelled', { orderId: this.cancelledOrderId })

      const order = await this.market.orderBook(this.cancelledOrderId)
      expect(order.status).to.be.bignumber.equal(this.orderStatus.CANCELLED)
    })
    it('disallows filling of cancelled order', async () => {
      await expectRevert(
        this.market.fillOrder(this.cancelledOrderId, { from: buyer1 }),
        'Market: order not fillable'
      )
    })
    it('allows cancellation of multiple orders', async () => {
      const tokens = [new BN('1'), new BN('2')]
      for (const token of tokens) {
        await this.market.createOrder(
          true,
          constants.ZERO_ADDRESS,
          this.nft.address,
          token,
          this.token.address,
          ether('8'),
          this.toInverseFee(this.fee),
          { from: seller1 }
        )
      }

      const cancelledOrderIds = [new BN('2'), new BN('3')]
      const receipt = await this.market.cancelOrders(cancelledOrderIds, { from: seller1 })
      for (const orderId of cancelledOrderIds) {
        expectEvent(receipt, 'OrderCancelled', { orderId })
        const order = await this.market.orderBook(orderId)
        expect(order.status).to.be.bignumber.equal(this.orderStatus.CANCELLED)
      }
    })
  })
})
