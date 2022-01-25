ethers = require('hardhat');

async function main() {

    owner = "0x652E3fA6353de83ac2b667368E75FEec05e9d5A9";

    const Factory = await ethers.ethers.getContractFactory("RentPoolFactory");
    const factory = await Factory.deploy(owner);

    console.log("Rent Pool Factory Contract deployed to:", factory.address);

}
main();
