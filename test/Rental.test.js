const { expect } = require("chai");
const { ethers } = require("hardhat");
const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");
const IUniswapV3PoolABI = require("../data/abi/@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json");
const { smartOrderRouter } = require('@uniswap/smart-order-router');
const { uniswapSDK } = require('@uniswap/sdk-core');
const PRECISE_UNIT = 1e18;

const V3_SWAP_ROUTER_ADDRESS = '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45';
const AlphaRouter = smartOrderRouter.AlphaRouter;
const Token = uniswapSDK.Token;
const CurrencyAmount = uniswapSDK.CurrencyAmount;



describe("Router", async () => {
    let router;
    let rentPoolFactory;
    let WETH;
    provider = new ethers.providers.Web3Provider(network.provider);


    it("router should deploy", async () => {
        [account] = await ethers.getSigners();
        FeeMath = await ethers.getContractFactory("FeeMath");
        feeMath = await FeeMath.deploy();
        Factory = await ethers.getContractFactory("RentPoolFactory");
        rentPoolFactory = await Factory.deploy(account.address);
        BlackScholes = await ethers.getContractFactory("BlackScholes");
        blackScholes = await BlackScholes.deploy();
        GreekCache = await ethers.getContractFactory("OptionGreekCache");
        greekCache = await GreekCache.deploy(account.address, BigInt(.01*PRECISE_UNIT), "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", BigInt(.17*PRECISE_UNIT));
        Router = await ethers.getContractFactory("CaravanRentRouter01", {
            libraries: {
                FeeMath: feeMath.address,
            },
        });
        WETHFactory = await ethers.getContractFactory("WETH");
        WETH = await WETHFactory.deploy();
        RentalPlatform = await ethers.getContractFactory("AutomatedRentPlatform");
        rentalPlatform = await RentalPlatform.deploy(account.address);
        RentalEscrow = await ethers.getContractFactory("AutomatedRentalEscrow");
        rentalEscrow = await RentalEscrow.deploy("0xC36442b4a4522E871399CD717aBDD847Ab11FE88",rentalPlatform.address,account.address);
        await rentalEscrow.setAutomatedRentalPlatform(rentalPlatform.address);
        await rentalPlatform.setRentalEscrow(rentalEscrow.address);
        router = await Router.deploy(rentPoolFactory.address,WETH.address,greekCache.address, blackScholes.address, "0x1F98431c8aD98523631AE4a59f267346ea31F984", rentalPlatform.address);
        console.log("Router contract deployed to:", router.address);

    });


    it("should add liquidity to both pools", async () => {
        // console.log(await provider.getBalance(account.address));
        // const poolAddress = "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8";
        daiAddr = "0x6b175474e89094c44da98b954eedeac495271d0f";
        WethAddr = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" ;
        const DAI = new Token(1, daiAddr, 18, "DAI", "Dai Coin");
        const router = new AlphaRouter({ chainId: 1, provider: provider });


        const WETH = new Token(1, WethAddr, 18, "WETH", "Wrapped Ether");
        wethAmount = CurrencyAmount.fromRawAmount(WETH, JSBI.BigInt(1))
        const route = await router.route( {
            amountIn: wethAmount,
            tokenOut: DAI,
            tradeType: TradeType.EXACT_IN,
            swapConfig: {
              recipient: account.address,
              slippage: new Percent(5, 100),
              deadline: 100
            },
        }

          );
          const transaction = {
            data: route.methodParameters.calldata,
            to: V3_SWAP_ROUTER_ADDRESS,
            value: BigNumber.from(route.methodParameters.value),
            from: MY_ADDRESS,
            gasPrice: BigNumber.from(route.gasPriceWei),
          };

        await provider.sendTransaction(transaction);
          

        // const poolContract = new ethers.Contract(
        //     poolAddress,
        //     IUniswapV3PoolABI,
        //     provider
        //     );
        // const quoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6";
        // const quoterContract = new ethers.Contract(quoterAddress, QuoterABI, provider);
        // const amountIn = 1500;
        // const quotedAmountOut = await quoterContract.callStatic.quoteExactInputSingle(
        //     daiAddr,
        //     WethAddr,
        //     0.05,
        //     amountIn.toString(),
        //     0
        //   );
        //   state = await getPoolState(poolContract);

        //   const WETHDAIPool = new Pool(
        //     WETH,
        //     DAI,
        //     0.05,
        //     state.sqrtPriceX96.toString(), //note the description discrepancy - sqrtPriceX96 and sqrtRatioX96 are interchangable values
        //     state.liquidity.toString(),
        //     state.tick
        //   );

        //   const swapRoute = new Route([WETHDAIPool], WETH, DAI);
        //   const uncheckedTrade = await Trade.createUncheckedTrade({
        //     route: swapRoute,
        //     inputAmount: CurrencyAmount.fromRawAmount(WETH, amountIn.toString()),
        //     outputAmount: CurrencyAmount.fromRawAmount(
        //       DAI,
        //       quotedAmountOut.toString()
        //     ),
        //     tradeType: TradeType.EXACT_INPUT,
        //   });



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
