const { expect } = require("chai");
const { ethers } = require("hardhat");

const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");

prov = ethers.getDefaultProvider();



beforeEach(async () => {
    [account] = await ethers.getSigners();
    Factory = await ethers.getContractFactory("RentPoolFactory");
    factory = await Factory.deploy(account.address);
    await factory.deployed();
})


//TODO: try running with hardhat and waffle
describe("RentPool", async () => {
    
    it("Should initialize from a factory with create pool", async () => {
        try {
        await factory.createPool("0x6b175474e89094c44da98b954eedeac495271d0f");
        poolContract = new web3.eth.Contract(rentPoolABI, "0x3794ddd191c296ef90e504d72d021c0efb04e0ca"); //pool Address is determnistic

        reserves  = await poolContract.methods.getReserves().call({from: account.address});
        console.log("RESERVES", reserves);

    } catch (e) {
        console.log(e);
        return e;
    }

    });

    it("should be able to mint from router", async() => {


    });

    it("should be able to burn from router", async() => {

    });
} )