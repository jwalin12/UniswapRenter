pragma solidity >=0.5.0;

interface IRentPool {


    function initialize(address _token) external;
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amountOfTokens, uint amountOfFees);
    function withdrawFees (address to) external returns (uint256 amountOfFees);
    function getReserves() external view returns (uint112 _reserve, uint112 feesAccrued, uint32 _blockTimestampLast);
    function skim(address to) external;
    function sync() external;


    
}