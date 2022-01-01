pragma solidity 0.7.6;
pragma abicoder v2;

import "./IRentPlatform.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';


interface IAutomatedRentalEscrow {

    mapping(address => mapping(int24 => mapping(int24 => uint256))) public getOldPositions;
    INonfungiblePositionManager public immutable UniswapNonFungiblePositionManager;


    function handleNewRental(uint256 tokenId, IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddr, address _renter) external;
    function handleExpiredRental(uint256 tokenId) external;
    function collectFeesForCurrentRenter(uint256 tokenId) external returns (uint256 token0amt, uint256 token1amt);
    function reuseOldPosition(uint256 tokenId, address uniswapPoolAddr, IRentPlatform.BuyRentalParams memory params) external;



}