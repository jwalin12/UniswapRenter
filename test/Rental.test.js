const { expect } = require("chai");
const { ethers } = require("hardhat");
const factoryABI = require("../data/abi/@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol/IUniswapV3Factory.json");
const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");
const IUniswapV3PoolABI = require("../data/abi/@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json");
// let {abi} = require("@uniswap/v3-periphery/artifacts/contracts/lens/Quoter.sol/Quoter.json");
const wethABI = require("../data/abi/contracts/WETH9.sol/WETH9.json");
const erc20ABI = require("../data/abi/contracts/ERC20.sol/ERC20.json");
const v3PoolABI = require("../data/abi/@uniswap/v3-core/contracts/UniswapV3Pool.sol/UniswapV3Pool.json")
const NFTManagerABI = require("../data/abi/@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol/INonfungiblePositionManager.json");
const { AlphaRouter, SWAP_ROUTER_ADDRESS, NONFUNGIBLE_POSITION_MANAGER_ADDRESS } = require('@uniswap/smart-order-router');
const  { Token, CurrencyAmount, Percent, MaxUint256, TradeType, Fraction,  }= require('@uniswap/sdk-core');
const { Pool, Route, Trade, SwapRouter, nearestUsableTick, TickMath, TICK_SPACINGS, FACTORY_ADDRESS, maxLiquidityForAmounts, LiquidityMath, isSorted } = require("@uniswap/v3-sdk");
const { getPoolState } = require("../utils/testing/pool.ts");
const { abi } = require("@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json");
const JSBI = require("jsbi");
const PRECISE_UNIT = 1e18;
const swapABI =abi;
// const V3_SWAP_ROUTER_ADDRESS = '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45';
// const QuoterABI = abi;
let router;
let rentPoolFactory;
let rentalEscrow;
let greekCache;
let account
let provider;
let uniswapV3PoolFactory;

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
        UniswapV3PoolFactory = await ethers.getContractFactory("UniswapV3Factory");
        uniswapV3PoolFactory = await UniswapV3PoolFactory.connect(account).deploy();
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
        WethContract.connect(account).deposit({value: await ethers.utils.parseEther('20')});
        await WethContract.connect(account).approve(SWAP_ROUTER_ADDRESS, await ethers.utils.parseEther('14'));



        const poolContract = await new ethers.Contract(
            "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8",
            v3PoolABI,
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
        fee: 3000,
        recipient: account.address,
        deadline: deadline,
        amountIn: await ethers.utils.parseEther('14'),
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0,
    };
        poolSlot0 = await poolContract.slot0();
        console.log("TOKEN0:",await poolContract.token0());
        await swapRouter.connect(account).exactInputSingle(ExactInputSingleParams);
        await console.log("WETH BAL", WethContract.balanceOf(account.address) > ethers.utils.parseEther("1") );
        rentalParams = {
        tickUpper: 60,
        tickLower: 0,
        fee: 3000,
        duration: 10000,
        priceMax: 10000000000000,
        token0: daiAddr,
        token1: WethAddr,
        amount0Desired: ethers.utils.parseEther("1"),
        amount1Desired: ethers.utils.parseEther("0"),
        amount0Min: ethers.utils.parseEther("1"),
        amount1Min: ethers.utils.parseEther("0"),
        deadline: deadline + 1000
        }

        PosManager = await new ethers.Contract(NONFUNGIBLE_POSITION_MANAGER_ADDRESS, NFTManagerABI, provider);
        await DaiContract.connect(account).approve(NONFUNGIBLE_POSITION_MANAGER_ADDRESS,ethers.utils.parseEther("10"));
        await WethContract.connect(account).approve(NONFUNGIBLE_POSITION_MANAGER_ADDRESS, ethers.utils.parseEther("10"));
        console.log(await DaiContract.allowance(account.address, NONFUNGIBLE_POSITION_MANAGER_ADDRESS));
        console.log(await WethContract.allowance(account.address, NONFUNGIBLE_POSITION_MANAGER_ADDRESS));

        // console.log(await PosManager.connect(account).mint({
        //     token0: rentalParams.token0,
        //     token1: rentalParams.token1,
        //     fee: rentalParams.fee,
        //     recipient: account.address,
        //     tickLower: rentalParams.tickLower,
        //     tickUpper: rentalParams.tickUpper,
        //     amount0Desired: rentalParams.amount0Desired,
        //     amount1Desired: rentalParams.amount1Desired,
        //     amount0Min: rentalParams.amount0Min,
        //     amount1Min: rentalParams.amount1Min,
        //     deadline: rentalParams.deadline +10000
        //     }));

        //check that liquidity amount added is not 0

        // poolSlot0 = await poolContract.slot0();
        // console.log("CURR POOL TICK", poolSlot0.tick);
        // sqrtRatioA = await TickMath.getSqrtRatioAtTick(rentalParams.tickLower);
        // sqrtRatioB = await TickMath.getSqrtRatioAtTick(rentalParams.tickUpper);
        // console.log("sqrt x96", poolSlot0.sqrtPriceX96);
        // const maxLiquidity = await maxLiquidityForAmounts(poolSlot0.sqrtPriceX96, sqrtRatioA, sqrtRatioB, rentalParams.amount0Desired, rentalParams.amount1Desired, true );
        // console.log("MAX LIQUIDITY", maxLiquidity);
        // await uniswapV3PoolFactory.connect(account).createPool(WethAddr,daiAddr, 2000);
        // poolAddr = await uniswapV3PoolFactory.getPool(WethAddr, daiAddr, 2000);
        // customPoolContract = await new ethers.Contract(poolAddr, v3PoolABI, provider);
        // await customPoolContract.connect(account).initialize(ethers.BigNumber.from("1415507735409115466500818218"));
        // await WethContract.connect(account).approve(poolAddr ,ethers.utils.parseEther("1"));
 
    //    await customPoolContract.connect(account).mint(account.address, 0, 60, ethers.BigNumber.from(maxLiquidity.toString()) ,[]);

        // factory = await new ethers.Contract(FACTORY_ADDRESS, factoryABI , provider);
        // console.log("FROM ETHERS",await factory.getPool(daiAddr, WethAddr, 3000));


        await rentPoolFactory.createPool(daiAddr);
        await rentPoolFactory.createPool(WethAddr);

        await DaiContract.connect(account).approve(NONFUNGIBLE_POSITION_MANAGER_ADDRESS,ethers.utils.parseEther('200'));
        await WethContract.connect(account).approve(NONFUNGIBLE_POSITION_MANAGER_ADDRESS, ethers.utils.parseEther('200'));
        await DaiContract.connect(account).approve(router.address, ethers.utils.parseEther('200'));
        await WethContract.connect(account).approve(router.address, ethers.utils.parseEther('200'));
        await router.addLiquidityETH(ethers.utils.parseEther('10'), ethers.utils.parseEther('0'), account.address, ethers.BigNumber.from(deadline),{ value: ethers.utils.parseEther('10') });
        console.log("APPROVAL OF DAI", await DaiContract.allowance(account.address, router.address));
        console.log("BAL OF DAI",await DaiContract.balanceOf(account.address) >ethers.utils.parseEther('10') );
        await router.addLiquidity(daiAddr, ethers.utils.parseEther('10'), ethers.utils.parseEther('0'), account.address, ethers.BigNumber.from(deadline)); 
        console.log("liquidty added");
        await router.connect(account).buyRental(rentalParams, { value: ethers.utils.parseEther('1') });
        console.log("MADE RENTAL W NO ERRORZ");
    




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
