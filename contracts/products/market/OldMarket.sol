// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDepositController.sol";
import "./ITokenVault.sol";

contract OldMarket is Ownable, IDepositController {
    uint256 public constant withdrawDelay = 7 days;
    uint256 public constant disputeTime = 3 days;
    uint256 public constant counterDisputeTime = 14 days;

    ITokenVault public immutable vault;

    struct Sale {
        address seller;
        uint256 price;
    }
    mapping(bytes32 => Sale) public sales;

    struct Payment {
        address buyer;
        uint256 amount;
        uint256 disputeStake;
        uint256 counterStake;
        uint256 unlockTime;
    }
    mapping(address => Payment[]) public payments;

    event SaleChanged(
        bytes32 indexed utid,
        address indexed seller,
        uint256 indexed price
    );

    constructor(address _vault) Ownable() {
        vault = ITokenVault(_vault);
    }

    function finalizePayment(address payable _seller, uint256 paymentIndex)
        external
    {
        Payment storage payment = payments[_seller][paymentIndex];
        require(payment.unlockTime > 0, "Market: Payment already executed");
        require(
            payment.unlockTime <= block.timestamp,
            "Market: Payment not yet unlocked"
        );
        payment.unlockTime = uint256(0);

        if (payment.disputeStake == 0) { // no dispute
            _seller.transfer(payment.amount);
        } else if (payment.counterStake == 0) { // dispute expired
            payable(payment.buyer).transfer(payment.amount + payment.disputeStake);
        } else { // counter dispute left unarbitrated
            uint256 firstHalf = payment.amount / 2;
            uint256 sellerRefund = firstHalf + payment.counterStake;
            bool success1 = _seller.send(sellerRefund);

            uint256 secondHalf = payment.amount - firstHalf;
            uint256 buyerRefund = secondHalf + payment.disputeStake;
            bool success2 = payable(payment.buyer).send(buyerRefund);

            if (!success1) payable(owner()).transfer(sellerRefund);
            if (!success2) payable(owner()).transfer(buyerRefund);
        }
    }

    function resolveDispute(
        address _seller,
        uint256 paymentIndex,
        bool forBuyer
    )
        external
        onlyOwner
    {
        Payment storage payment = payments[_seller][paymentIndex];
        require(
            payment.unlockTime > 0 && payment.unlockTime > block.timestamp,
            "Market: Payment complete"
        );
        require(
            payment.disputeStake > 0 && payment.counterStake > 0,
            "Market: No arbitration initiated"
        );
        payment.unlockTime = uint256(0);

        uint256 arbitrationFee;
        address payable refundRecipient;

        if (forBuyer) {
            arbitrationFee = payment.counterStake / uint256(5);
            refundRecipient = payable(payment.buyer);
        } else {
            arbitrationFee = payment.counterStake / uint256(5);
            refundRecipient = payable(_seller);
        }

        uint256 refundAmount = payment.amount +
            payment.disputeStake +
            payment.counterStake -
            arbitrationFee;

        bool success = refundRecipient.send(refundAmount);
        if (!success) {
            arbitrationFee += refundAmount;
        }
        payable(owner()).transfer(arbitrationFee);
    }

    function counterDispute(uint256 paymentIndex) external payable {
        Payment storage payment = payments[msg.sender][paymentIndex];
        require(
            payment.unlockTime > 0 && payment.unlockTime > block.timestamp,
            "Market: Payment complete"
        );
        require(payment.disputeStake > 0, "Market: No dispute initiated");
        require(
            msg.value == payment.disputeStake,
            "Market: Counter must match stake"
        );
        require(payment.counterStake == 0, "Market: Counter already started");

        payment.unlockTime = block.timestamp + counterDisputeTime;
        payment.counterStake = msg.value;
    }

    function dispute(address _seller, uint256 paymentIndex) external payable {
        require(msg.value > 0, "Market: No dispute stake");
        Payment storage payment = payments[_seller][paymentIndex];
        require(
            payment.unlockTime > 0 && payment.unlockTime <= block.timestamp,
            "Market: Payment complete"
        );
        require(payment.buyer == msg.sender, "Market: Only buyer may dispute");
        require(payment.disputeStake == 0, "Market: Dispute already started");

        payment.unlockTime = block.timestamp + disputeTime;
        payment.disputeStake = msg.value;
    }

    function completeSale(bytes32 _utid) external payable {
        address seller = sales[_utid].seller;
        require(seller != address(0), "Market: No sale");
        require(sales[_utid].price == msg.value, "Market: Must pay exactly");
        payments[seller].push(Payment({
            buyer: msg.sender,
            amount: msg.value,
            disputeStake: uint256(0),
            counterStake: uint256(0),
            unlockTime: block.timestamp + withdrawDelay
        }));
        setSale(_utid, address(0), uint256(0));
        vault.withdrawToken(_utid, msg.sender, "");
    }

    function cancelSale(bytes32 _utid) external {
        require(sales[_utid].seller == msg.sender, "Market: Only seller may cancel");
        setSale(_utid, address(0), uint256(0));
        vault.withdrawToken(_utid, msg.sender, "");
    }

    function onTokenDeposit(
        address _depositor,
        bytes32 _utid,
        bytes calldata _data
    )
        external
        override
    {
        require(msg.sender == address(vault), "Market: Only vault may deposit");
        uint256 salePrice = abi.decode(_data, (uint256));
        require(salePrice > 0, "Market: Invalid price");
        require(sales[_utid].seller == address(0), "Market: Sale already has seller");
        setSale(_utid, _depositor, salePrice);
    }

    function paymentCount(address _seller) public view returns(uint256) {
        return payments[_seller].length;
    }

    function setSale(
        bytes32 _utid,
        address newSeller,
        uint256 newSalePrice
    )
        internal
    {
        sales[_utid] = Sale({
            seller: newSeller,
            price: newSalePrice
        });
        emit SaleChanged(_utid, newSeller, newSalePrice);
    }
}
