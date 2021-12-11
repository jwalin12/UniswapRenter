pragma solidity = 0.7.6;

import "./interfaces/IRentPoolFactory.sol";




contract RentPoolFactory is IRentPoolFactory {

    address UniswapV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;


    address public feeTo; //who the fees go to
    address public feeToSetter; //who sets where the fee goes to

    mapping(address => mapping(address => address)) public getPool;
    address[] public allPools;

    constructor(address _feeToSetter) public {
        feeToSetter() = _feeToSetter;
    }

    function allPoolsLength() external view returns (uint) {
        return allPools.length;
    }

    function createPool(address uniswapV3Pool) exte




}