const BN = require('bn.js');
const Agora = artifacts.require('Agora');
const Merchandise = artifacts.require('Merchandise');
const Calculate = artifacts.require('Calculate');
const ILogisticsLookup = artifacts.require('ILogisticsLookup');
const ILogisticsLookupAddress = '0xfb14c19cd86bc7e2c7fce9c3701ab69aa1f058c5';

contract('Returning', (accounts) => {
    let agora;
    let merchandise;
    let calculate;
    let logisticsLookup;

    const deployer = accounts[0];
    const seller = accounts[1];
    const buyer = accounts[2];

    const tokenId = '1';
    const decimals = 2;
    const amount = 2;
    const uintPrice = 1.2;
    const logisticsNo = '1Z222E910320176644';
    const logisticsNoReturned = '1Z136E761028174156';
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
        // Buyer approval to management items
        await merchandise.setApprovalForAll(agora.address, true, { from: buyer });
        // Set the state of the seller's item to be delivered
        logisticsLookup.setLogisticsState(web3.utils.keccak256(logisticsNo), '2');
        // Set the state of the buyer's returned item to be delivered
        logisticsLookup.setLogisticsState(web3.utils.keccak256(logisticsNoReturned), '2');
    });

    it('Initialize', async () => {
        await agora.initialize(merchandise.address, logisticsLookup.address);
    });

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

    it('Item was shipped', async () => {
        await agora.ship(tokenId, buyer, logisticsNo, { from: seller });
        // Check logistics info
        const logisticsInfo = await agora.logisticsInfo(tokenId, buyer);
        assert.equal(logisticsInfo.logisticsNo, logisticsNo);
    });

    it('Item was delivered', async () => {
        // Set item delivered
        await agora.deliver(tokenId, buyer);
        // Check logistics info
        const logisticsInfo = await agora.logisticsInfo(tokenId, buyer);
        assert.notEqual(logisticsInfo.completeTime.toString(), '0');
    });

    it('Buyer wants to return an item', async () => {
        // Set item back
        await agora.returning(tokenId, '1', logisticsNoReturned, shippingAddressHash, { from: buyer });

        // Check logistics info
        const logisticsInfo = await agora.logisticsInfo(tokenId, seller);
        assert(logisticsInfo.seller.toString(), buyer);
    });

    it('Buyer confirms item delivered', async () => {
        // Seller
        const amountBefore = await merchandise.balanceOf(seller, tokenId);
        // Set item delivered
        await agora.deliver(tokenId, seller);
        // Check Buyer returned items
        const amountAfter = await merchandise.balanceOf(seller, tokenId);
        assert.equal(amountBefore.add(new BN(1)).toString(), amountAfter.toString());
        // Check logistics info
        const logisticsInfo = await agora.logisticsInfo(tokenId, buyer);
        assert.notEqual(logisticsInfo.completeTime.toString(), '0');
    });

    it('Set return period to 0 days', async () => {
        await agora.setReturnPeriod('0');
        const blocknumber = await agora.getReturnPeriod();
        assert.equal(blocknumber.toString(), '0');
    });

    it('Buyer settle a transaction', async () => {
        const balanceBefore = await web3.eth.getBalance(buyer);
        await agora.settle(tokenId, seller, { from: buyer });
        const balanceAfter = await web3.eth.getBalance(buyer);
        
        let b1 = new BN(balanceBefore);
        let b2 = new BN(balanceAfter);
        assert.equal(b2.cmp(b1), 1);
    });
})
