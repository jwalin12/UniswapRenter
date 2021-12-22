pragma solidity 0.7.6

contract OptionGreekCache {

    mapping(address => uint256) private poolAddressToVol;
    mapping(address => bool) private authorizedUsers;
    address private owner;
    uint256 private riskFreeRate;

    constructor() {
        authorizedUsers[msg.sender] = true;
        owner = msg.sender;
    }

    getRiskFreeRate() external pure returns (uint256) {
        return riskFreeRate;
    }

    setRiskFreeRate(uint256 newRate) external {
        require(authorizedUsers[msg.sender], 'Unauthorized user');
        riskFreeRate = newRate;
    }

    getVol(address poolAddr) external pure returns (uint256) {
        return poolAddressToVol[poolAddr];
    }

    setPoolAddressToVol(address poolAddr, uint256 newVol) external {
        require(authorizedUsers[msg.sender], 'Unauthorized user');
        poolAddressToVol[poolAddr] = newVol;
    }

    //adding and removing authorized users can only be done by owner of contract
    addAuthorizedUser(address newUser) external {
        require(msg.sender == owner, 'Unauthorized user');
        authorizedUsers[newUser] = true;
    }

    removeAuthorizedUser(address userToRemove) external {
        require(msg.sender == owner, 'Not the owner');
        authorizedUsers[userToRemove] = false;
    }

}