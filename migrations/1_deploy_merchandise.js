const Merchandise = artifacts.require('Merchandise');

module.exports = async (deployer) => {
    deployer.deploy(Merchandise, { overwrite: true });
}