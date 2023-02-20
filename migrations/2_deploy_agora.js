const States = artifacts.require('States');
const Errors = artifacts.require('Errors');
const Calculate = artifacts.require('Calculate');
const DataTypes = artifacts.require('DataTypes');
const Agora = artifacts.require('Agora');
const TradeLogic = artifacts.require('TradeLogic');

module.exports = async (deployer) => {
    deployer.deploy(States, { overwrite: true });
    deployer.deploy(Errors, { overwrite: true });
    deployer.deploy(Calculate, { overwrite: true });
    deployer.deploy(DataTypes, { overwrite: true });
    deployer.link(States, TradeLogic);
    deployer.link(Calculate, TradeLogic);
    deployer.link(Errors, [TradeLogic, Agora]);
    deployer.link(DataTypes, [TradeLogic, Agora]);
    deployer.deploy(TradeLogic, { overwrite: true });
    deployer.link(TradeLogic, Agora);
    deployer.deploy(Agora, { overwrite: true });
}