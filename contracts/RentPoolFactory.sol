pragma solidity = 0.7.6;

import "./interfaces/IRentPoolFactory.sol";


contract RentPoolFactory is IRentPoolFactory {

    address UniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;


    address private _feeTo; //who the fees go to
    address private _feeToSetter; //who sets where the fee goes to
    mapping(address => address) public tokenToPool;
    address[] public allPools;

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

    function createPool(address uniswapV3Pool) override external returns (address rentPool) {
        return address(0);
    }

    function setFeeTo(address to) external override  {
        require(msg.sender == _feeToSetter, "UNAUTHORIZED");
        _feeTo = to;
    }

    function setFeeToSetter(address to) external override  {
        require(msg.sender == _feeToSetter, "UNAUTHORIZED");
        _feeToSetter = to;
    }

}