const { ethers } = require("hardhat");
const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");
const wethABI = require("../data/abi/contracts/WETH9.sol/WETH9.json");
const erc20ABI = require("../data/abi/contracts/ERC20.sol/ERC20.json");
const v3PoolABI = require("../data/abi/@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json")
const swapABI = require("../data/abi/@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol/ISwapRouter.json");
const { expect } = require("chai");
const PRECISE_UNIT = 1e18;
let router;
let rentPoolFactory;
let rentalEscrow;
let greekCache;
let provider;
let deadline;
let rentalParams;
let tokenId;
let poolContract;
let swapRouter;
let account2;
let account;


const FACTORY_ADDRESS = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const SWAP_ROUTER_ADDRESS = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

before(async () => {
    
    provider = await new ethers.providers.Web3Provider(network.provider);
    [account, account2] = await ethers.getSigners();
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

        RentalPlatform = await ethers.getContractFactory("AutomatedRentPlatform");
        rentalPlatform = await RentalPlatform.deploy(account.address);
        RentalEscrow = await ethers.getContractFactory("AutomatedRentalEscrow");
        rentalEscrow = await RentalEscrow.deploy("0xC36442b4a4522E871399CD717aBDD847Ab11FE88",rentalPlatform.address,account.address);
        await rentalEscrow.setAutomatedRentalPlatform(rentalPlatform.address);
        await rentalPlatform.setRentalEscrow(rentalEscrow.address);
        router = await Router.deploy(rentPoolFactory.address,"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",greekCache.address, blackScholes.address, rentalPlatform.address, FACTORY_ADDRESS, account.address, account.address, 0);
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
        WethContract.connect(account2).deposit({value: await ethers.utils.parseEther('20')});
        await WethContract.connect(account).approve(SWAP_ROUTER_ADDRESS, await ethers.utils.parseEther('14'));
        await WethContract.connect(account2).approve(SWAP_ROUTER_ADDRESS, await ethers.utils.parseEther('14'));



        poolContract = await new ethers.Contract(
            "0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8",
            v3PoolABI,
            provider
        );



        blockNumber = await provider.getBlockNumber();
        block = await provider.getBlock(blockNumber);
        timestamp = block.timestamp;
        deadline = timestamp + 864000

        greekCache.connect(account).setPoolAddressToVol("0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8", BigInt(.94*PRECISE_UNIT));

        swapRouter = await new ethers.Contract(SWAP_ROUTER_ADDRESS, swapABI, provider);
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
        await console.log("DAI BAL", DaiContract.balanceOf(account.address) > ethers.utils.parseEther("1") );
        rentalParams = {
            tickUpper: -14940,
            tickLower: -15000,
            fee: 3000,
            duration: 10000,
            priceMax: 10000000000000,
            token0: daiAddr,
            token1: WethAddr,
            amount0Desired: ethers.utils.parseEther("0.000001"),
            amount1Desired: ethers.utils.parseEther("0"),
            amount0Min: ethers.utils.parseEther("0.000001"),
            amount1Min: ethers.utils.parseEther("0"),
            deadline: deadline + 100000
        }
        await rentPoolFactory.createPool(daiAddr);
        await rentPoolFactory.createPool(WethAddr);
        await DaiContract.connect(account).approve(router.address, ethers.utils.parseEther('20'));
        await WethContract.connect(account).approve(router.address, ethers.utils.parseEther('20'));
        await router.addLiquidityETH(ethers.utils.parseEther('10'), ethers.utils.parseEther('0'), account.address, ethers.BigNumber.from(deadline),{ value: ethers.utils.parseEther('10') });
        await router.addLiquidity(daiAddr, ethers.utils.parseEther('10'), ethers.utils.parseEther('0'), account.address, ethers.BigNumber.from(deadline)); 
        await router.connect(account).buyRental(rentalParams, { value: ethers.utils.parseEther('1') });
        daiPoolAddr = await rentPoolFactory.getPool(daiAddr);
        daiRentPool = await new ethers.Contract(daiPoolAddr, rentPoolABI, provider);
        console.log(await daiRentPool.getReserves());

    });

    it("should create a rental", async () => {
        tokenId = await rentalPlatform.rentalsInProgress(0)
        expect(tokenId !=0, "rental not created");
        rentInfoParams = rentalPlatform.getRentalInfoParams(tokenId)
        expect(rentInfoParams[0] == rentalEscrow.address,"incorrect original owner");
        expect(rentInfoParams[1] == account.address, "INCORRECT RENTER");
        expect(rentInfoParams[4] == poolContract.address, "INCORRECT V3 POOL");
        expect(rentInfoParams[2] == tokenId, "TokenIds do not match up!");


    });


    it("should allow fees to be collected", async () => {
        await rentalPlatform.collectFeesForRenter(tokenId, 0, 0);

    });



    // it("should return error when collecting fees when rental is up", async () => {
    //     await network.provider.send("evm_setNextBlockTimestamp", [deadline +100001]);
    //     expect(await rentalPlatform.collectFeesForRenter(await rentalPlatform.rentalsInProgress(0), 0, 0));

    // });
    it("should end rental", async () => {
        await network.provider.send("evm_setNextBlockTimestamp", [deadline +100003]);
        await rentalPlatform.endRental(await rentalPlatform.rentalsInProgress(0));


    });

    it ("should reuse old position", async () => {
        ExactInputSingleParams.recipient = account2.address;
        ExactInputSingleParams.deadline = deadline +100050;
        await swapRouter.connect(account2).exactInputSingle(ExactInputSingleParams);
        rentalParams.deadline = deadline +100050
        await console.log("DAI BAL ACCT 2", await DaiContract.balanceOf(account2.address));
        await DaiContract.connect(account2).approve(router.address, ethers.utils.parseEther('20'));
        await WethContract.connect(account2).approve(router.address, ethers.utils.parseEther('20'));
        await router.connect(account2).buyRental(rentalParams, { value: ethers.utils.parseEther('1') });
        expect(await rentalPlatform.rentalsInProgress(0) == tokenId, "position not reused");
        rentInfoParams = rentalPlatform.getRentalInfoParams(tokenId);
        expect(rentInfoParams[0] == rentalEscrow.address,"incorrect original owner");
        expect(rentInfoParams[1] == account.address, "INCORRECT RENTER");
        expect(rentInfoParams[4] == poolContract.address, "INCORRECT V3 POOL");
        expect(rentInfoParams[2] == tokenId, "TokenIds do not match up!");
    });



    it ("should not reuse old position when it is being used", async () => {
        rentalParams.deadline = deadline +100050
        await router.connect(account).buyRental(rentalParams, { value: ethers.utils.parseEther('1')});
        expect(await rentalPlatform.rentalsInProgress(1) != 0, "not creating new position");
        expect(await rentalPlatform.rentalsInProgress(1) != tokenId, "reusing old position");
        rentInfoParams = rentalPlatform.getRentalInfoParams(tokenId)
        expect(rentInfoParams[0] == rentalEscrow.address,"incorrect original owner");
        expect(rentInfoParams[1] == account.address, "INCORRECT RENTER");
        expect(rentInfoParams[4] == poolContract.address, "INCORRECT V3 POOL");
        expect(rentInfoParams[2] == tokenId, "TokenIds do not match up!");
    });

    





});
