const { assert } = require('console');
const Web3 = require('web3');
const Contract = require('web3-eth-contract');

// set provider for all later instances to use
web3 =  new Web3(new Web3.providers.HttpProvider('https://rinkeby.infura.io/v3/b3727224cb254a1b80a8a9f7368e6a99'));
const contract = new Contract([],'0xc79226118CB5aee4d6d35654132b987c1aB56aAe');

function testPutUpNFTForRent() {

    contract.methods.putUpNFTForRent(7595,10,1000,'0xc2e9f25be6257c210d7adf0d4cd6e3e881ba25f8').call({from: '0x652E3fA6353de83ac2b667368E75FEec05e9d5A9'});
    assert(contract.itemIdToRentInfo.size() == 1);
    assert(contract.itemIdToRentInfo[7595].originalOwner == '0x652E3fA6353de83ac2b667368E75FEec05e9d5A9');
    assert(contract.itemIdToRentInfo[7595].duration == 1000);
    assert(contract.itemIdToRentInfo[7595].price == 10);
    assert(contract.itemIdToRentInfo[7595].expiry == 0);
    assert(contract.itemIdToRentInfo[7595].renter == '0x0000000000000000000000000000000000000000');
    contract.methods.removeNFTForRent(7595).send({from: '0x652E3fA6353de83ac2b667368E75FEec05e9d5A9'});
    

}
testPutUpNFTForRent();
