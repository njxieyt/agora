const BN = require('bn.js');
const Agora = artifacts.require('Agora');
const Merchandise = artifacts.require('Merchandise');
const Calculate = artifacts.require('Calculate');
const ILogisticsLookup = artifacts.require('ILogisticsLookup');
const ILogisticsLookupAddress = '0xfb14c19cd86bc7e2c7fce9c3701ab69aa1f058c5';

contract('Agora', (accounts) => {
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

    before('Get contract instance', async () => {
        agora = await Agora.new();
        merchandise = await Merchandise.new();
        calculate = await Calculate.new();
        logisticsLookup = await ILogisticsLookup.at(ILogisticsLookupAddress);
        await merchandise.transferOwnership(agora.address);
        await merchandise.setApprovalForAll(agora.address, true, { from: seller });
    });

    it('Initialize', async () => {
        await agora.initialize(merchandise.address, logisticsLookup.address);
    });

    it('Set margin rate', async () => {
        // Set rate to 20%
        let rate = 20 * 10 ** decimals;
        await agora.setMarginRate(rate.toString());
        const marginRate = await agora.getMarginRate();
        assert.equal(marginRate.toString(), rate);
    });

    it('Set fee rate', async () => {
        // Set rate to 0.2%
        let rate = 0.2 * 10 ** decimals;
        await agora.setFeeRate(rate.toString());
        const feeRate = await agora.getFeeRate();
        assert.equal(feeRate.toString(), rate.toString());
    });

    it('Calculate margin price', async () => {
        let marginPrice, fee;
        let totalPrice = amount * uintPrice;
        const marginRate = await agora.getMarginRate();
        const feeRate = await agora.getFeeRate();
        await calculate.marginPrice(web3.utils.toWei(totalPrice.toString()), marginRate, feeRate).then((res) => {
            marginPrice = res[0];
            fee = res[1];
        });
        assert.equal((totalPrice * marginRate / 10000), web3.utils.fromWei(marginPrice));
        assert.equal((totalPrice * feeRate / 10000), web3.utils.fromWei(fee));
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
        const shippingAddress = '9999 Columbia Rd NW #999, Washington, DC 20009';
        const shippingAddressHash = web3.utils.keccak256(shippingAddress);
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
    })

    it('Item was delivered', async () => {
        // Mock logistics state
        logisticsLookup.setLogisticsState(web3.utils.keccak256(logisticsNo), '2');
        // Set item delivered
        await agora.deliver(tokenId, buyer);
        // Check logistics info
        const logisticsInfo = await agora.logisticsInfo(tokenId, buyer);
        assert.notEqual(logisticsInfo.completeTime.toString(), '0');
    })

    it('Seller settle a transaction', async () => {
        await agora.settle(tokenId, buyer, { from: seller });
        // Check buyer owns an item
        const amountToken = await merchandise.balanceOf(buyer, tokenId);
        assert.equal(amountToken.toString(), '1');
    })
})
