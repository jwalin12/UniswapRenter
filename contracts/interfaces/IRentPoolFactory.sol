pragma solidity >=0.5.0;

interface IRentPoolFactory {
    event PoolCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPool(address uniswapV3Pool) external view returns (address rentPool);
    function allPools(uint) external view returns (address pair);
    function allPoolsLength() external view returns (uint);

    function createPool(address uniswapV3Pool) external returns (address rentPool);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}