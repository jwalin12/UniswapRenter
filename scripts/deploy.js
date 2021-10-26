

ethers = require('hardhat');
async function main() {
    // We get the contract to deploy
    const [deployer] = await ethers.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const owner = "0x652E3fA6353de83ac2b667368E75FEec05e9d5A9";
    const Contract = await ethers.ethers.getContractFactory("NonfungiblePositionPlatform");
    const contract = await Contract.deploy(owner); //last arg is placeholder
  
    console.log("Contract deployed to:", contract.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });