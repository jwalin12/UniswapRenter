

ethers = require('hardhat');
async function main() {
    // We get the contract to deploy
    const [deployer] = await ethers.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const owner = "0x652E3fA6353de83ac2b667368E75FEec05e9d5A9";
    const Contract = await ethers.ethers.getContractFactory("OptionPlatform");
    const contract = await Contract.deploy(owner, 200); 
    //last arg is marketplace fee. A 1% fee is represented by an int 100. MUST BE AN INT. Thus, the fee can only be up to 2 decimal points of precision.
  
    console.log("Contract deployed to:", contract.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });