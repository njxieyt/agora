const Agora = artifacts.require('Agora');
const Merchandise = artifacts.require('Merchandise');
const ILogisticsLookup = '0xfb14c19cd86bc7e2c7fce9c3701ab69aa1f058c5';

contract('Agora', (accounts) => {
    let agora;
    const deployer = accounts[0]
    const seller = accounts[1]
    const buyer = accounts[2]

    before('Get Contract Instance', async () => {
        agora = await Agora.deployed();
        const merchandiseInstance = await Merchandise.deployed();
        console.log('mToken owner', await merchandiseInstance.owner());
        //await merchandiseInstance.transferOwnership(agora.address);
    });
    /*it('initialize', async () => {
        const merchandiseInstance = await Merchandise.deployed();
        await agora.initialize(merchandiseInstance.address, ILogisticsLookup);
    });*/
    it('Sell 2 items with a unit price 1.2 ether', async () => {
        const amount = '2';
        const price = '1.2';
        const newUri = 'https://etherscan.io/images/svg/brands/ethereum-original.svg';
        const tokenId = await agora.sell(amount, web3.utils.toWei(price), newUri, { from: seller, value: web3.utils.toWei('2') });
        assert.isAbove(tokenId.toNumber(), 0, 'tokenId:' + tokenId);
    });
})