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

    address _approvedLiqudityManager;

    uint256 public _fee; //fee is divided by 10000, so 2 is 0.02% fee
    uint256 public feesAccrued;
    uint256 public totalFeesAccrued;


    function recieve() external payable {
        feesAccrued += msg.value;
        totalFeesAccrued += msg.value;

    }


    function setApprovedLiquidityManager(address newManager) external override {
        _approvedLiqudityManager = newManager;
    }


    function approvedLiqudityManager() external override view returns (address) {
        return _approvedLiqudityManager;
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


    function drawLiquidity(address token0, address token1, uint256 amount0, uint256 amount1, address to) external override {
        require(msg.sender == _approvedLiqudityManager, "UNAUTHORIZED");
        IRentPool pool0 = IRentPool(tokenToPool[token0]); 
        require(address(pool0) != address(0), "POOL NOT INITIALIZED");
        IRentPool pool1 =  IRentPool(tokenToPool[token1]); 
        require(address(pool1) != address(0), "POOL NOT INITIALIZED");
        pool0.sendLiquidity(amount0, to);
        pool1.sendLiquidity(amount1, to);
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
        require(msg.sender == _feeToSetter, "UNAUTHORIZED");
        require(newFee >= 0, "INVALID FEE");
        _fee = newFee;

    }
    function getFee() external view override returns (uint256) {
        return _fee;

    }


}