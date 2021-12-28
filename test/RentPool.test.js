const { expect } = require("chai");
const { ethers } = require("hardhat");

const rentPoolABI = require("../data/abi/contracts/RentPool.sol/RentPool.json");

prov = ethers.getDefaultProvider();

//TODO: try running with hardhat and waffle
contract("RentPool", async () => {
    
    it("Should initialize from a factory with create pool", async (accounts) => {
        try {
        console.log("DEPLOYING");
        const [owner] = await ethers.getSigners();
        //console.log(await prov.getBalance(owner.address));
        const Factory = await ethers.getContractFactory("RentPoolFactory");
        const factory = await Factory.deploy(owner.address);
        await factory.deployed();
        console.log("DEPLOYED");
        const pool = factory.createPool("0x6b175474e89094c44da98b954eedeac495271d0f").connect(owner).done();
       
        console.log("POOL", pool);
    } catch (e) {
        return e;
    }
        // let poolContract = new web3.eth.Contract(rentPoolABI, pool);
        // let reserves  = await poolContract.methods.getReserves().send({ from: accounts[0] })
        // console.log("RESERVES", reserves);


    });


    it("should be able to mint from router", async() => {



    });

    it("should be able to burn from router", async() => {

    });
} )