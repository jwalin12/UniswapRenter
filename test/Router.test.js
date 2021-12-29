const { expect } = require("chai");
const { assert, time } = require("console");
const { ethers } = require("hardhat");

const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider("https://rinkeby.infura.io/v3/24c74b1a2d234298a3a757ccdf0997bc"));

const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");
const rentPoolFactoryABI = require("../data/abi/contracts/RentPoolFactory.sol/RentPoolFactory.json");
const routerABI = require("../data/abi/contracts/CaravanRentRouter01.sol/CaravanRentRouter01.json");
const greekCacheABI = require("../data/abi/contracts/OptionGreekCache.sol/OptionGreekCache.json");
const { ok } = require("assert");
const { factory } = require("typescript");

const blackScholesAddr = "0x70F307DE576f088046f42a8B38584e8B8A7e2BF9"
const greekCacheAddr =  "0xf2E8AD22Dd52f3C3f9303557246ccAA6fA946Fe3"
const rentPoolFactoryAddr = "0x580A727184A03571e2022b11acB6B927988beECF"
const routerAddress = "0xF6b4ce5e164603ac3D010093EC2d5E5de70B1AC9"
const WETHAddress = "0xc778417e063141139fce010982780140aa0cd5ab"

beforeEach(async () => {
    accounts = await web3.eth.getAccounts();
    console.log("DEFAULT ACCT", web3.eth.defaultAccount);
    
    router = await new web3.eth.Contract(routerABI, routerAddress);
    console.log("router got");
    greekCache = await new web3.eth.Contract(greekCacheABI, greekCacheAddr);
    console.log("cache got");
    rentPoolFactory = await new web3.eth.Contract(rentPoolFactoryABI, rentPoolFactoryAddr);
})

describe("Router", async () => {


    it("Should initialize", () => {
        console.log(router._address);
    })

    it("should be able to get price data", async() => {
        console.log(router.methods.getRentalPrice(10, 12, 6000, "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8").send({from: accounts[0]}));
    });

    it("should be able to add liquidity in ETH from router", async() => {

        blockNumber = web3.eth.blockNumber;
        timestamp = web3.eth.getBlock(blockNumber).timestamp;
        const origBal = web3.eth.Eth.get_balance(accounts[0]);
        let origReserve;

        poolAddr = rentPoolFactory.methods.getPool(WETH);
        if (poolAddr == "0x0000000000000000000000000000000000000000") {
            origReserve = 0;
            
        } else {
            WETHPool = await new web3.eth.Contract(rentPoolABI, poolAddr);

            origReserve = WETHPool.methods.getReserves().send({from:accounts[0]})._reserve;

        }

        router.methods.addLiquidityETH(100, 100, accounts[0], timestamp + 100000).send({from:accounts[0]});
        assert(rentPoolFactory.methods.getPool(WETH).send({from:accounts[0]}) != "0x0000000000000000000000000000000000000000");

        //check token balance of user
        assert(web3.eth.get_balance(accounts[0]) == (origBal -100));
        //add liquidity

        //check pool reserves
        poolAddr = rentPoolFactory.methods.getPool(WETH);

        WETHPool = await new web3.eth.Contract(rentPoolABI, poolAddr);

        newReserve = WETHPool.methods.getReserves().send({from:accounts[0]})._reserve;

        assert(origReserve + 100 == newReserve);

        //check token balance of user

    });


    it("should be able to burn liquidity in ETH from router", async() => {

        //check pool reserves

        //check token balance of user


        //remove liquidity


        //check pool reserves

        //check token balance of user


    });


});