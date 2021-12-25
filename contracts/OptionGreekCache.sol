pragma solidity = 0.7.6;

contract OptionGreekCache {

    mapping(address => uint256) private poolAddressToVol;
    mapping(address => bool) private authorizedUsers;
    address private owner;
    int256 private riskFreeRate;

    constructor(address _owner) {
        authorizedUsers[_owner] = true;
        owner = _owner;
    }

    function getRiskFreeRate() external view returns (int256) {
        return riskFreeRate;
    }

    function setRiskFreeRate(int256 newRate) external {
        require(authorizedUsers[msg.sender], "Unauthorized user");
        riskFreeRate = newRate;
    }

    function getVol(address poolAddr) external view returns (uint256) {
        return poolAddressToVol[poolAddr];
    }

    function setPoolAddressToVol(address poolAddr, uint256 newVol) external {
        require(authorizedUsers[msg.sender], "Unauthorized user");
        poolAddressToVol[poolAddr] = newVol;
    }

    //adding and removing authorized users can only be done by owner of contract
    function addAuthorizedUser(address newUser) external {
        require(msg.sender == owner, 'Unauthorized user');
        authorizedUsers[newUser] = true;
    }

    function removeAuthorizedUser(address userToRemove) external {
        require(msg.sender == owner, 'Not the owner');
        authorizedUsers[userToRemove] = false;
    }

}