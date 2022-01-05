pragma solidity 0.7.6;
pragma abicoder v2;

interface IRentPlatform {

    struct BuyRentalParams {
        int24 tickUpper;
        int24 tickLower;
        uint24 fee;
        uint256 duration;
        uint256 priceMax;
        address token0;
        address token1;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct RentInfo {
        address payable originalOwner;
        address payable renter;
        uint256 tokenId;
        uint256 expiryDate;
        address uniswapPoolAddress;
    }


    function createNewRental(IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddr, address _renter) external returns (uint256 tokenId,
            uint256 amount0, uint256 amount1);

    function endRental(uint256 tokenId) external;

    function collectFeesForRenter(uint256 tokenId, uint256 token0Min, uint256 token1Min) external returns (uint256, uint256);
}
