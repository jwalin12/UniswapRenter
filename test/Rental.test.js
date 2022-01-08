const { expect } = require("chai");
const { ethers } = require("hardhat");
const factoryABI = require("../data/abi/@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol/IUniswapV3Factory.json");
const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");
const IUniswapV3PoolABI = require("../data/abi/@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json");
// let {abi} = require("@uniswap/v3-periphery/artifacts/contracts/lens/Quoter.sol/Quoter.json");
const wethABI = require("../data/abi/contracts/WETH9.sol/WETH9.json");
const erc20ABI = require("../data/abi/contracts/ERC20.sol/ERC20.json");
const { AlphaRouter, SWAP_ROUTER_ADDRESS, NONFUNGIBLE_POSITION_MANAGER_ADDRESS } = require('@uniswap/smart-order-router');
const  { Token, CurrencyAmount, Percent, MaxUint256, TradeType, Fraction }= require('@uniswap/sdk-core');
const { Pool, Route, Trade, SwapRouter, nearestUsableTick, TickMath, TICK_SPACINGS, FACTORY_ADDRESS } = require("@uniswap/v3-sdk");
const { getPoolState } = require("../utils/testing/pool.ts");
const { abi } = require("@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json");
const JSBI = require("jsbi");
const PRECISE_UNIT = 1e18;
const swapABI =abi;
// const V3_SWAP_ROUTER_ADDRESS = '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45';
// const QuoterABI = abi;
let router;
let rentPoolFactory;
let greekCache;
let account
let provider;

before(async () => {
    
    provider = await new ethers.providers.Web3Provider(network.provider);
    [account] = await ethers.getSigners();
  });



describe("Router", () => {
    
    it("router should deploy", async () => {
        FeeMath = await ethers.getContractFactory("FeeMath");
        feeMath = await FeeMath.deploy();
        Factory = await ethers.getContractFactory("RentPoolFactory");
        rentPoolFactory = await Factory.deploy(account.address);
        BlackScholes = await ethers.getContractFactory("BlackScholes");
        blackScholes = await BlackScholes.deploy();
        GreekCache = await ethers.getContractFactory("OptionGreekCache");
        greekCache = await GreekCache.deploy(account.address, BigInt(.1*PRECISE_UNIT), "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", BigInt(.17*PRECISE_UNIT));
        Router = await ethers.getContractFactory("CaravanRentRouter01", {
            libraries: {
                FeeMath: feeMath.address,
            },
        });
        ETHDAISwapper = await ethers.getContractFactory("SwapExamples");
        swapper = await ETHDAISwapper.deploy(SWAP_ROUTER_ADDRESS);
        RentalPlatform = await ethers.getContractFactory("AutomatedRentPlatform");
        rentalPlatform = await RentalPlatform.deploy(account.address);
        RentalEscrow = await ethers.getContractFactory("AutomatedRentalEscrow");
        rentalEscrow = await RentalEscrow.deploy("0xC36442b4a4522E871399CD717aBDD847Ab11FE88",rentalPlatform.address,account.address);
        await rentalEscrow.setAutomatedRentalPlatform(rentalPlatform.address);
        await rentalPlatform.setRentalEscrow(rentalEscrow.address);
        router = await Router.deploy(rentPoolFactory.address,"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",greekCache.address, blackScholes.address, rentalPlatform.address, FACTORY_ADDRESS);
        console.log("Router contract deployed to:", router.address);

    });


    it("should add liquidity to both pools", async () => {
        // console.log(await provider.getBalance(account.address));
        const poolAddress = "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8";
        daiAddr = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
        WethAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" ;

        DaiContract = await new ethers.Contract(daiAddr, erc20ABI, provider);

        WethContract = await new ethers.Contract(WethAddr, wethABI, provider);
        WethContract.connect(account).deposit({value: 1500});
        console.log(await WethContract.connect(account).approve(SWAP_ROUTER_ADDRESS, 1400));



        const poolContract = await new ethers.Contract(
            poolAddress,
            IUniswapV3PoolABI,
            provider
            );

        blockNumber = await provider.getBlockNumber();
        block = await provider.getBlock(blockNumber);
        timestamp = block.timestamp;
        const deadline = timestamp + 864000

        greekCache.connect(account).setPoolAddressToVol(poolAddress, 1);

        const swapRouter = await new ethers.Contract(SWAP_ROUTER_ADDRESS, swapABI, provider);
        ExactInputSingleParams = {
        tokenIn: WethAddr,
        tokenOut: daiAddr,
        fee: ethers.BigNumber.from(3000),
        recipient: account.address,
        deadline: deadline,
        amountIn: ethers.BigNumber.from(1400),
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0,
    };
    console.log(ExactInputSingleParams);
        await swapRouter.connect(account).exactInputSingle(ExactInputSingleParams);
        rentalParams = {
        tickUpper: TickMath.MAX_TICK,
        tickLower: TickMath.MIN_TICK,
        fee: 3000,
        duration: 10000,
        priceMax: 10000000000000,
        token0: daiAddr,
        token1: WethAddr,
        amount0Desired: 100,
        amount1Desired: 100,
        amount0Min:0,
        amount1Min: 0,
        deadline: deadline +1000
        }
        console.log(TickMath.MIN_TICK);
        factory = await new ethers.Contract(FACTORY_ADDRESS, factoryABI , provider);
        console.log("FROM ETHERS",await factory.getPool(daiAddr, WethAddr, 3000));
        await DaiContract.connect(account).approve(NONFUNGIBLE_POSITION_MANAGER_ADDRESS,100);
        await WethContract.connect(account).approve(NONFUNGIBLE_POSITION_MANAGER_ADDRESS, 100);

        await router.connect(account).buyRental(rentalParams);
    




    });

    it("should create a rental", async () => {

    });


    it("should split fees correctly", async () => {

    });

    it("should allow renter to collect fees", async () => {

    });

    it("should return rental when time is up", async () => {

    });





});
