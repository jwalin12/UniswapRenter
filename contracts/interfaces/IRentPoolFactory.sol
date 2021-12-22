pragma solidity >=0.5.0;

interface IRentPoolFactory {
    event PoolCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPool(address token) external view returns (address rentPool);
    function getAllPools(uint) external view returns (address[] memory allPools);
    function allPoolsLength() external view returns (uint);

    function createPool(address uniswapV3Pool) external returns (address rentPool);

    function setFeeTo(address to) external;
    function setFeeToSetter(address to) external;
}