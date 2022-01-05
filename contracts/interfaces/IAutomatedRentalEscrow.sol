pragma solidity 0.7.6;
pragma abicoder v2;

import "./IRentPlatform.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';


interface IAutomatedRentalEscrow {


    function getUniswapPositionManager() external returns (address);
    function getOldPositions(address uniswapPoolAddr, int24 tickUpper, int24 tickLower) external returns (uint256 tokenId) ;
    function handleNewRental(uint256 tokenId, IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddr, address _renter) external;
    function handleExpiredRental(uint256 tokenId) external;
    function collectFeesForCurrentRenter(uint256 tokenId) external returns (uint256 token0amt, uint256 token1amt);
    function reuseOldPosition(uint256 tokenId, address uniswapPoolAddr, IRentPlatform.BuyRentalParams memory params) external returns(uint256 amount0, uint256 amount1);



}