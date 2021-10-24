

ethers = require('hardhat');
async function main() {
    // We get the contract to deploy
    const [deployer] = await ethers.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const V3Factory = '0x1F98431c8aD98523631AE4a59f267346ea31F984';
    const WETH9 = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const Contract = await ethers.ethers.getContractFactory("NonfungiblePositionManager");
    const contract = await Contract.deploy(V3Factory,WETH9, V3Factory); //last arg is placeholder
  
    console.log("Contract deployed to:", contract.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });