const { expect } = require("chai");
const { ethers } = require("hardhat");
const assert = require('assert');
const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider("https://rinkeby.infura.io/v3/e3331c80e072400b9410eba420d79697"));

const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");
const routerABI = require("../data/abi/contracts/CaravanRentRouter01.sol/CaravanRentRouter01.json");
const greekCacheABI = require("../data/abi/contracts/OptionGreekCache.sol/OptionGreekCache.json");
const { ok } = require("assert");

const blackScholesAddr = "0x70F307DE576f088046f42a8B38584e8B8A7e2BF9"
const greekCacheAddr =  "0xf2E8AD22Dd52f3C3f9303557246ccAA6fA946Fe3"
const rentPoolFactoryAddr = "0x580A727184A03571e2022b11acB6B927988beECF"
const routerAddress = "0xF6b4ce5e164603ac3D010093EC2d5E5de70B1AC9"

prov = ethers.getDefaultProvider();

beforeEach(async () => {
    accounts = await web3.eth.getAccounts();
    router = await new web3.eth.Contract(routerABI, routerAddress);
    console.log("router got");
    greekCache = await new web3.eth.Contract(greekCacheABI, greekCacheAddr);
    console.log("cache got");
})

describe("Router", async () => {


    it("Should initialize", () => {
        console.log(router._address);
    })

    it("should be able to get price data", async() => {
        console.log(router.methods.getRentalPrice(10, 12, 6000, "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8").send({from: accounts[0]}));
    });

    it("should be able to burn from router", async() => {
    });
});