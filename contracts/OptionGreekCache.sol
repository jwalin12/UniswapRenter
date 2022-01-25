pragma solidity = 0.7.6;

// Libraries
import "./synthetix/SignedSafeDecimalMath.sol";
import "./synthetix/SafeDecimalMath.sol";
import "./interfaces/IOptionGreekCache.sol";

contract OptionGreekCache is IOptionGreekCache  {
    using SafeMath for uint;
    using SafeDecimalMath for uint;
    using SignedSafeMath for int;
    using SignedSafeDecimalMath for int;

    mapping(address => uint256) private poolAddressToVol;
    mapping(address => bool) private authorizedUsers;
    address private owner;
    int256 private riskFreeRate;

    constructor(address _owner, int256 _riskFreeRate, address testAddr, uint256 testVol) {
        authorizedUsers[_owner] = true;
        riskFreeRate = _riskFreeRate;
        poolAddressToVol[testAddr] = testVol;
        owner = _owner;
    }

    function getRiskFreeRate() external override view returns (int256) {
        return riskFreeRate;
    }

    function setRiskFreeRate(int256 newRate) external override {
        require(authorizedUsers[msg.sender], "Unauthorized user");
        riskFreeRate = newRate;
    }

    function getVol(address poolAddr) external override view returns (uint256) {
        return poolAddressToVol[poolAddr];
    }

    function setPoolAddressToVol(address poolAddr, uint256 newVol) external override {
        require(authorizedUsers[msg.sender], "Unauthorized user");
        poolAddressToVol[poolAddr] = newVol;
    }

    //adding and removing authorized users can only be done by owner of contract
    function addAuthorizedUser(address newUser) external override {
        require(msg.sender == owner, 'Unauthorized user');
        authorizedUsers[newUser] = true;
    }

    function removeAuthorizedUser(address userToRemove) external override {
        require(msg.sender == owner, 'Not the owner');
        authorizedUsers[userToRemove] = false;
    }

}