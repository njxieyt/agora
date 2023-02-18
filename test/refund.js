const BN = require('bn.js');
const { assertRevert } = require('./utils/assert-revert');
const Agora = artifacts.require('Agora');
const Merchandise = artifacts.require('Merchandise');
const Calculate = artifacts.require('Calculate');
const ILogisticsLookup = artifacts.require('ILogisticsLookup');
const ILogisticsLookupAddress = '0xfb14c19cd86bc7e2c7fce9c3701ab69aa1f058c5';

contract('Refund', (accounts) => {
    let agora;
    let merchandise;
    let calculate;
    let logisticsLookup;

    const seller = accounts[1];
    const buyer = accounts[2];

    const tokenId = '1';
    const amount = 2;
    const uintPrice = 1.2;
    const logisticsNo = '1Z222E910320176644';
    const shippingAddress = '9999 Columbia Rd NW #999, Washington, DC 20009';
    const shippingAddressHash = web3.utils.keccak256(shippingAddress);

    before('Get contract instance', async () => {
        agora = await Agora.new();
        merchandise = await Merchandise.new();
        calculate = await Calculate.new();
        logisticsLookup = await ILogisticsLookup.at(ILogisticsLookupAddress);
        // Set owner of Merchandise is Agora contract
        await merchandise.transferOwnership(agora.address);
        // Seller approval to management items
        await merchandise.setApprovalForAll(agora.address, true, { from: seller });
    });

    it('Initialize', async () => {
        await agora.initialize(merchandise.address, logisticsLookup.address);
    });

    it('Set return period to 0 days', async () => {
        await agora.setReturnPeriod('0');
        const blocknumber = await agora.getReturnPeriod();
        assert.equal(blocknumber.toString(), '0');
    })

    it('Sell two items for 1.2 ether each', async () => {
        const totalPrice = amount * uintPrice;
        const marginRate = await agora.getMarginRate();
        const feeRate = await agora.getFeeRate();
        const totalPay = (totalPrice * marginRate / 10000) + (totalPrice * feeRate / 10000);
        const newUri = 'https://etherscan.io/images/svg/brands/ethereum-original.svg';
        await agora.sell(amount.toString(), web3.utils.toWei(uintPrice.toString()), newUri,
            { from: seller, value: web3.utils.toWei(totalPay.toString()) });
        const currentTokenId = await agora.currentTokenId();
        assert.equal(currentTokenId.toString(), tokenId);
        // Check who owns the item
        const amountToken = await merchandise.balanceOf(seller, tokenId);
        assert.equal(amountToken.toString(), amount.toString());
    });

    it('Buy one item', async () => {
        await agora.buy(tokenId, '1', shippingAddressHash,
            { from: buyer, value: web3.utils.toWei(uintPrice.toString()) });

        const logisticsInfo = await agora.logisticsInfo(tokenId, buyer);

        assert.equal(shippingAddressHash.toString(), logisticsInfo.deliveryAddress.toString());
    });

    it('Buyer wants a refund', async () => {
        const balanceBefore = await web3.eth.getBalance(buyer);
        await agora.refund(tokenId, { from: buyer });

        const balanceAfter = await web3.eth.getBalance(buyer);

        let b1 = new BN(balanceBefore);
        let b2 = new BN(balanceAfter);
        assert.equal(b2.cmp(b1), 1);
    });

    // Test revert case
    it('Item could not be shipped', async () => {
        await assertRevert(agora.ship(tokenId, buyer, logisticsNo, { from: seller }));
    });

    it('Item could not be delivered', async () => {
        await assertRevert(agora.deliver(tokenId, buyer));
    });

    it('Seller was unable to settle the transaction', async () => {
        await assertRevert(agora.settle(tokenId, buyer, { from: seller }));
    });
})
