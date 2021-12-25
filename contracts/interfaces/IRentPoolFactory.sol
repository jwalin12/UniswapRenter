pragma solidity >=0.5.0;

interface IRentPoolFactory {
    event PoolCreated(address indexed token, address pool, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPool(address token) external view returns (address rentPool);
    function getAllPools(uint) external view returns (address[] memory allPools);
    function allPoolsLength() external view returns (uint);

    function createPool(address uniswapV3Pool) external returns (address rentPool);

    function setFeeTo(address to) external;
    function setFeeToSetter(address to) external;

    function setFee(uint256 newFee) external;
    function getFee(uint256 newFee) external view returns (uint256);

    function withdrawProtocolFees() external;
}