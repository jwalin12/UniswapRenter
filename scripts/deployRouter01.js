
ethers = require('hardhat');
const PRECISE_UNIT = 1e18;
const FACTORY_ADDRESS = "0x1F98431c8aD98523631AE4a59f267346ea31F984";

async function main() {
  const [account] = await ethers.ethers.getSigners();
  console.log("OWNER:", account.address);
  FeeMath = await ethers.ethers.getContractFactory("FeeMath");
  feeMath = await FeeMath.deploy();
  Factory = await ethers.ethers.getContractFactory("RentPoolFactory");
  rentPoolFactory = await Factory.deploy(account.address);
  console.log("rent pool factory deployed to:", rentPoolFactory.address);
  BlackScholes = await ethers.ethers.getContractFactory("BlackScholes");
  blackScholes = await BlackScholes.deploy();
  console.log("black scholes deployed to:", blackScholes.address);
  GreekCache = await ethers.ethers.getContractFactory("OptionGreekCache");
  greekCache = await GreekCache.deploy(account.address, BigInt(.1*PRECISE_UNIT), "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", BigInt(.17*PRECISE_UNIT));
  console.log("greek cache deployed to:", greekCache.address);
  Router = await ethers.ethers.getContractFactory("CaravanRentRouter01", {
      libraries: {
          FeeMath: feeMath.address,
      },
  });
  RentalPlatform = await ethers.ethers.getContractFactory("AutomatedRentPlatform");
  rentalPlatform = await RentalPlatform.deploy(account.address);
  console.log("rent platform deployed to:", rentalPlatform.address);
  RentalEscrow = await ethers.ethers.getContractFactory("AutomatedRentalEscrow");
  rentalEscrow = await RentalEscrow.deploy("0xC36442b4a4522E871399CD717aBDD847Ab11FE88",rentalPlatform.address,account.address);
  console.log("rent escrow deployed to:", rentalEscrow.address);
  await rentalEscrow.setAutomatedRentalPlatform(rentalPlatform.address);
  await rentalPlatform.setRentalEscrow(rentalEscrow.address);
  router = await Router.deploy(rentPoolFactory.address,"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",greekCache.address, blackScholes.address, rentalPlatform.address, FACTORY_ADDRESS, account.address, account.address, 0);
  console.log("Router contract deployed to:", router.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });