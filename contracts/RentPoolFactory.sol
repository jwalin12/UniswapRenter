pragma solidity = 0.7.6;
pragma abicoder v2;

import "./interfaces/IRentPoolFactory.sol";
import "./interfaces/IRentPool.sol";
import "./RentPool.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Create2.sol";


contract RentPoolFactory is IRentPoolFactory {

    address UniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address private _feeTo; //who the fees go to
    address private _feeToSetter; //who sets where the fee goes to
    mapping(address => address) public tokenToPool;
    address[] public allPools;

    uint256 public _fee; //fee is divided by 10000, so 2 is 0.02% fee
    uint256 public feesAccrued;
    uint256 public totalFeesAccrued;


    function recieve() external payable {
        feesAccrued += msg.value;
        totalFeesAccrued += msg.value;


    }

    function feeTo() external override view returns (address) {
        return _feeTo;
    }

    function feeToSetter() external override view returns (address) {
        return _feeToSetter;
    }

    constructor(address feeToSetter) public {
        _feeToSetter = feeToSetter;
    }

    function allPoolsLength() override external view returns (uint) {
        return allPools.length;
    }

    function getPool(address token) external override view returns (address rentPool) {
        return tokenToPool[token];
    }
    function getAllPools(uint) override external view returns (address[] memory allPools){
        return allPools;
    }

    function createPool(address token) override external returns (address pool) {
        require(token != address(0),"ZERO_ADDRESS");
        require(tokenToPool[token] == address(0), "POOL_EXISTS"); 
        bytes memory bytecode = type(RentPool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token, "CARAVAN"));
        bytes32 bytecodeHash =keccak256(abi.encodePacked(type(RentPool).creationCode));
        pool = Create2.deploy(0, salt, bytecode);
        console.log(pool);
        IRentPool(pool).initialize(token);
        tokenToPool[token] = pool;
        allPools.push(pool);
        console.log("INIT SUCCESFULLY");
        emit PoolCreated(token, pool, allPools.length);

    }

    function setFeeTo(address to) external override  {
        require(msg.sender == _feeToSetter, "UNAUTHORIZED");
        _feeTo = to;
    }

    function setFeeToSetter(address to) external override  {
        require(msg.sender == _feeToSetter, "UNAUTHORIZED");
        _feeToSetter = to;
    }

    function setFee(uint256 newFee) external override {
        // require(msg.sender == _feeToSetter, "UNAUTHORIZED");
        // _fee = newFee;

    }
    function getFee(uint256 newFee) external view override returns (uint256) {
        return _fee;

    }

    function withdrawProtocolFees() external override {
        // require(msg.sender == _feeToSetter, "UNAUTHORIZED");
        // uint256 currFees = feesAccrued;
        // feesAccrued = 0;
        // payable(_feeTo).transfer(currFees);

    }

}