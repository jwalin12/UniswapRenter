
ethers = require('hardhat');
async function main() {
    // We get the contract to deploy
    const [deployer] = await ethers.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const owner = "0x652E3fA6353de83ac2b667368E75FEec05e9d5A9";
    const BlackScholes = await ethers.ethers.getContractFactory("BlackScholes");
    const blackScholes = await BlackScholes.deploy(); 
    //last arg is marketplace fee. A 1% fee is represented by an int 100. MUST BE AN INT. Thus, the fee can only be up to 2 decimal points of precision.
    
    console.log("Black Scholes Contract deployed to:", blackScholes.address);


    const GreekCache = await ethers.ethers.getContractFactory("OptionGreekCache");
    const greekCache = await GreekCache.deploy(owner);

    console.log("Greek Cache Contract deployed to:", greekCache.address);

    const Factory = await ethers.ethers.getContractFactory("RentPoolFactory");
    const factory = await Factory.deploy(owner);

    console.log("Rent Pool Factory Contract deployed to:", factory.address);




    const Router = await ethers.ethers.getContractFactory("CaravanRentRouter01");
    const WETH = "0xc778417e063141139fce010982780140aa0cd5ab"
    const router = await Router.deploy(factory.address,WETH,greekCache.address, blackScholes.address);

    console.log("Router contract deployed to:", router.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });