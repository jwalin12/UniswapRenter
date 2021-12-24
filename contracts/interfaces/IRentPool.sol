pragma solidity >=0.5.0;

interface IRentPool {


    function initialize(address _token) external;
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amountOfTokens, uint amountOfFees);
    function skim(address to) external;
    function sync() external;




    
}