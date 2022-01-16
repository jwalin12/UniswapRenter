const { expect } = require("chai");
const { assert, time } = require("console");
const { ethers } = require("hardhat");
const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");
const v3PoolABI = require("../data/abi/@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json");
// const { FACTORY_ADDRESS } = require("@uniswap/v2-sdk");
const PRECISE_UNIT = 1e18;
const FACTORY_ADDRESS = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; //v3 pool factory address
const intToDecimals = async (i, tokenAddress) => {
    const prov = new ethers.providers.Web3Provider(network.provider);
    const abi = [
        "function balanceOf(walletAddress) view returns (uint256)",
        "function decimals() view returns (uint256)"
      ];
    const tok = new ethers.Contract(tokenAddress, abi, prov);
    const decimals = await tok.decimals();
    console.log(decimals, i/decimals)
    return i / decimals;
};

describe("Router", async () => {

    let router;
    let rentPoolFactory;
    let WETH;
    let greekCache;
    provider = new ethers.providers.Web3Provider(network.provider);


    it("should deploy",async () => {
        [account] = await ethers.getSigners();
        FeeMath = await ethers.getContractFactory("FeeMath");
        feeMath = await FeeMath.deploy();
        Factory = await ethers.getContractFactory("RentPoolFactory");
        rentPoolFactory = await Factory.deploy(account.address);
        BlackScholes = await ethers.getContractFactory("BlackScholes");
        blackScholes = await BlackScholes.deploy();
        GreekCache = await ethers.getContractFactory("OptionGreekCache");
        greekCache = await GreekCache.deploy(account.address, BigInt(.01*PRECISE_UNIT), "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", BigInt(.94*PRECISE_UNIT));
        Router = await ethers.getContractFactory("CaravanRentRouter01", {
            libraries: {
                FeeMath: feeMath.address,
            },
        });
        RentalPlatform = await ethers.getContractFactory("AutomatedRentPlatform");
        rentalPlatform = await RentalPlatform.deploy(account.address);
        RentalEscrow = await ethers.getContractFactory("AutomatedRentalEscrow");
        rentalEscrow = await RentalEscrow.deploy("0xC36442b4a4522E871399CD717aBDD847Ab11FE88",rentalPlatform.address,account.address);
        await rentalEscrow.setAutomatedRentalPlatform(rentalPlatform.address);
        await rentalPlatform.setRentalEscrow(rentalEscrow.address);
        router = await Router.deploy(rentPoolFactory.address, "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", greekCache.address, blackScholes.address, rentalPlatform.address, FACTORY_ADDRESS, account.address, account.address, 0);
        console.log("Router contract deployed to:", router.address);
    });

    it("should be able to get price data", async() => {
        try {
            const poolContract = await new ethers.Contract(
                "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8",
                v3PoolABI,
                provider
            );
            greekCache.connect(account).setPoolAddressToVol("0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8", BigInt(.94*PRECISE_UNIT));
            const daiAddr = "0x6b175474e89094c44da98b954eedeac495271d0f";
            const WethAddr = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" ;
            const blockNumber = await provider.getBlockNumber();
            const block = await provider.getBlock(blockNumber);
            const timestamp = block.timestamp;
            const lowerTick = -82944; //81609; // ETH/USDC = $3500 per ETH = 3499.90807274
            const upperTick = -81609; //82944; // ETH/USDC = $4000 per ETH = 3999.74267845
            const yearInSeconds = 31556926; // # of secs per year
            const duration = yearInSeconds;
            rentalParams = {
                tickUpper: upperTick,
                tickLower: lowerTick,
                fee: 3000,
                duration: duration,
                priceMax: 10000000000000,
                token0: daiAddr,
                token1: WethAddr,
                amount0Desired: ethers.utils.parseEther("0.000001"),
                amount1Desired: ethers.utils.parseEther("0.000001"),
                amount0Min: ethers.utils.parseEther("0.000001"),
                amount1Min: ethers.utils.parseEther("0"),
                deadline: timestamp + duration
            }
            // console.log("Rental Params:", rentalParams)
            let rentalPrice = await router.quoteRental(rentalParams);
            console.log("Got rental price:", rentalPrice)
            let testPrice = await router.test(upperTick, lowerTick, duration, "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8", ethers.utils.parseEther("0.000001"), ethers.utils.parseEther("0.000001"));
            console.log("Test price:", testPrice.call, testPrice.put, testPrice.vol, testPrice.token0Decimals);
        } catch (e) {
            if (e != null) {
                console.log(e);
                console.log("Error when getting price data");
            }
            expect(e == null, "error %v", e);
        }            
        
    });

    // it("should be able to not return zero price", async() => {
    //     try {
    //         const poolContract = await new ethers.Contract(
    //             "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8",
    //             v3PoolABI,
    //             provider
    //         );
    //         greekCache.connect(account).setPoolAddressToVol("0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8", BigInt(.94*PRECISE_UNIT));
    //         const lowerTick = -887272; //81609; // ETH/USDC = $3500 per ETH = 3499.90807274
    //         const upperTick = 887272; //82944; // ETH/USDC = $4000 per ETH = 3999.74267845
    //         const daiAddr = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    //         const WethAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" ;
    //         const blockNumber = await provider.getBlockNumber();
    //         const block = await provider.getBlock(blockNumber);
    //         const timestamp = block.timestamp;
    //         const duration = 10000;
    //         rentalParams = {
    //             tickUpper: upperTick,
    //             tickLower: lowerTick,
    //             fee: 3000,
    //             duration: duration,
    //             priceMax: 10000000000000,
    //             token0: daiAddr,
    //             token1: WethAddr,
    //             amount0Desired: ethers.utils.parseEther("0.000001"),
    //             amount1Desired: ethers.utils.parseEther("0"),
    //             amount0Min: ethers.utils.parseEther("0.000001"),
    //             amount1Min: ethers.utils.parseEther("0"),
    //             deadline: timestamp + duration
    //         }
    //         let rentalPrice = await router.connect(account).quoteRental(rentalParams, { value: ethers.utils.parseEther('1') });
    //         console.log(rentalPrice);
    //     } catch (e) {
    //         if (e != null) {
    //             console.log(e);
    //             console.log("Error when getting price data");
    //         }
    //         expect(e == null, "error %v", e);
    //     }            
        
    // });


    // it("should be able to get price data", async() => {
    //     try {

            

    //         const lowerTick = 81609; // ETH/USDC = $3500 per ETH = 3499.90807274
    //         const upperTick = 82944; // ETH/USDC = $4000 per ETH = 3999.74267845
    //         const yearInSeconds = 31556926; // # of secs per year
    //         let rentalPrice = await router.test(lowerTick, upperTick, yearInSeconds, "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", BigInt(100*PRECISE_UNIT));
    //         console.log(rentalPrice);
    //     } catch (e) {
    //         if (e != null) {
    //             console.log(e);
    //             console.log("Error when getting price data");
    //         }
    //         expect(e == null, "error %v", e);
    //     }            
    // });


    // it("should be able to add and remove ETH liquidity", async() => {

    //     try {
    //         blockNumber = await provider.getBlockNumber();
    //         block = await provider.getBlock(blockNumber);
    //         timestamp = block.timestamp;
    //         const deadline = timestamp + 864000
    //         const origBal = await provider.getBalance(account.address)
    //         poolAddr = await rentPoolFactory.getPool(WETH.address);
    //         expect(poolAddr == "0x0000000000000000000000000000000000000000", "POOL ADDR NOT 0");
    //         await router.addLiquidityETH(ethers.utils.parseEther('10'), ethers.utils.parseEther('0'), account.address, ethers.BigNumber.from(deadline),{ value: ethers.utils.parseEther('11') });
    //         poolAddr = await rentPoolFactory.getPool(WETH.address);

    //         //check token balance of user
    //         expect(await provider.getBalance(account.address) == (origBal-ethers.utils.parseEther('10')),  "FUNDS NOT TAKEN FROM SENDER");
            
    //         //add liquidity

    //         //check pool reserves
    //         WETHPool = await new ethers.Contract(poolAddr, rentPoolABI, account);
    //         let newReserve = await WETHPool.getReserves()
    //         expect(ethers.utils.parseEther('1') == newReserve, "FUNDS NOT SENT TO POOL");
    //         console.log("ACCT LP BALANCE", await WETHPool.balanceOf(account.address));
    //         //TODO: try approving smt 
    //         await WETHPool.approve(router.address, ethers.utils.parseEther('1'));
    //         await router.removeLiquidityETH(ethers.utils.parseEther('0.1'), ethers.utils.parseEther('0'),ethers.utils.parseEther('0'), account.address, ethers.BigNumber.from(deadline));
    //         expect(await provider.getBalance(account.address) == origBal-ethers.utils.parseEther('0.01')+ethers.utils.parseEther('0.0000001') ,  "FUNDS NOT RETURNED TO SENDER");

    //     } catch (e) {
    //         if (e != null) {
    //             console.log(e);
    //             console.log("Error when working with pool liquidity");
    //         }
    //         expect(e == null, "error %v", e);
    //     }
          

    // });

        
        


});
