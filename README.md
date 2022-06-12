# Basic Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/sample-script.js
npx hardhat help

npx hardhat run scripts/deploySomething.js --network rinkeby
```

If you get an issue with TypeError: Only absolute URLs are supported, check the hardhat.config.ts and make sure you have put your infura node URL as the url and you have access to an account with ETH on that network.
