const { expect } = require("chai");
const { assert, time } = require("console");
const { ethers } = require("hardhat");
const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");






describe("Router", async () => {

    let router;
    let rentPoolFactory;
    let WETH;
    provider = new ethers.providers.Web3Provider(network.provider)



    it("should deploy",async () => {
        [account] = await ethers.getSigners();
        Factory = await ethers.getContractFactory("RentPoolFactory");
        rentPoolFactory = await Factory.deploy(account.address);
        BlackScholes = await ethers.getContractFactory("BlackScholes");
        blackScholes = await BlackScholes.deploy();
        GreekCache = await ethers.getContractFactory("OptionGreekCache");
        greekCache = await GreekCache.deploy(account.address, 2, "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8", BigInt(10e23));
        Router = await ethers.getContractFactory("CaravanRentRouter01");
        WETHFactory = await ethers.getContractFactory("WETH");
        WETH = await WETHFactory.deploy();
        router = await Router.deploy(rentPoolFactory.address,WETH.address,greekCache.address, blackScholes.address, "0x1F98431c8aD98523631AE4a59f267346ea31F984");
        console.log("Router contract deployed to:", router.address);
        
    });


    // it("should be able to get price data", async() => {
    //     console.log(await router.getRentalPrice(10, 12, 6000, "0x1F98431c8aD98523631AE4a59f267346ea31F984"));
    // });


    it("should be able to add and remove ETH liquidity", async() => {
        try {

            blockNumber = await provider.getBlockNumber();
            block = await provider.getBlock(blockNumber);
            timestamp = block.timestamp;
            const deadline = timestamp + 864000
            const origBal = await provider.getBalance(account.address)
            poolAddr = await rentPoolFactory.getPool(WETH.address);
            expect(poolAddr == "0x0000000000000000000000000000000000000000", "POOL ADDR NOT 0");
            await router.addLiquidityETH(ethers.utils.parseEther('10'), ethers.utils.parseEther('0'), account.address, ethers.BigNumber.from(deadline),{ value: ethers.utils.parseEther('11') });
            poolAddr = await rentPoolFactory.getPool(WETH.address);

            //check token balance of user
            expect(await provider.getBalance(account.address) == (origBal-ethers.utils.parseEther('10')),  "FUNDS NOT TAKEN FROM SENDER");
            
            //add liquidity

            //check pool reserves
            WETHPool = await new ethers.Contract(poolAddr, rentPoolABI, account);
            let newReserve = await WETHPool.getReserves()
            expect(ethers.utils.parseEther('1') == newReserve, "FUNDS NOT SENT TO POOL");
            //TODO: try approving smt 
            await router.removeLiquidityETH(ethers.utils.parseEther('0.0000000000001'), ethers.utils.parseEther('0'),ethers.utils.parseEther('0'), account.address, ethers.BigNumber.from(deadline));
            expect(await provider.getBalance(account.address) == origBal-ethers.utils.parseEther('0.01')+ethers.utils.parseEther('0.0000001') ,  "FUNDS NOT RETURNED TO SENDER");

        } catch (e) {
            if (e != null) {
                console.log(e);
            }
            expect(e == null, "error %v", e);

        }

    });

        
        


});
