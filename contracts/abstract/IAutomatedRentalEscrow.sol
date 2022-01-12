pragma solidity 0.7.6;
pragma abicoder v2;

import "./IRentPlatform.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';


abstract contract IAutomatedRentalEscrow {


    mapping(uint256 => IRentPlatform.RentInfo) public tokenIdToRentInfo;

    function getUniswapPositionManager() external virtual returns (address);
    function getOldPositions(address uniswapPoolAddr, int24 tickUpper, int24 tickLower) external virtual returns (uint256 tokenId) ;
    function handleNewRental(uint256 tokenId, IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddr, address _renter) external virtual;
    function handleExpiredRental(uint256 tokenId) external virtual;
    function collectFeesForCurrentRenter(uint256 tokenId) external virtual returns (uint256 token0amt, uint256 token1amt);
    function handleReuseOldPosition(uint256 tokenId, address uniswapPoolAddr, IRentPlatform.BuyRentalParams memory params) external virtual returns(uint256 amount0, uint256 amount1);



}