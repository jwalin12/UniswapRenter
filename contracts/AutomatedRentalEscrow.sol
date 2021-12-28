pragma solidity 0.7.6;
pragma abicoder v2;


import "./interfaces/IRentPlatform.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';


contract AutomatedRentalEscrow is IRentPlatform {

    mapping(address => mapping(int24 => mapping(int24 => uint256))) getOldPositions; //Maps uniswapv3Pool -> ticklower -> tickupper -> tokenID
    mapping(uint256 => RentInfo) public tokenIdToRentInfo;

    INonfungiblePositionManager private immutable UniswapNonFungiblePositionManager;

    constructor(address uniswapNFTPositionManagerAddress) { 
        UniswapNonFungiblePositionManager = INonfungiblePositionManager(uniswapNFTPositionManagerAddress);
    
    }


    function createNewRental(BuyRentalParams memory params, address uniswapPoolAddr, address _renter) external override {

        uint256 tokenId = getOldPositions[uniswapPoolAddr][params.tickUpper][params.tickLower];
        if (tokenId != 0) {
            _reuseOldPosition(tokenId, uniswapPoolAddr, params);
        }

        else {
            (uint256 tokenID, , , ) = UniswapNonFungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
            token0: params.token0,
            token1: params.token1,
            fee: params.fee,
            recipient: address(this),
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min,
            deadline: params.deadline
            })
            );

        }
        tokenIdToRentInfo[tokenId] = RentInfo({
            originalOwner: payable(address(this)),
            renter: payable(_renter),
            tokenId: tokenId,
            expiryDate: block.timestamp + params.duration,
        
            uniswapPoolAddress: uniswapPoolAddr
        });

        
    }

    function reclaimRental(uint256 tokenId) external override {
        RentInfo memory rentInfo = tokenIdToRentInfo[tokenId];
        require(msg.sender == rentInfo.originalOwner, "UNAUTHORIZED RECLAMATION");
        require(block.timestamp >= rentInfo.expiryDate, "RENTAL NOT YET EXPIRED");
        tokenIdToRentInfo[tokenId].renter = address(0);
        returnLiquidity(tokenId);
        (
            ,
           ,
           ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            ,
            ,
            ,
            ,
           
        ) = UniswapNonFungiblePositionManager.positions(tokenId);

        getOldPositions[rentInfo.uniswapPoolAddress][tickLower][tickUpper] = tokenId;

    }


    function returnLiquidity(uint256 tokenId) private {
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,
            
        )=  UniswapNonFungiblePositionManager.positions(tokenId);
       
        UniswapNonFungiblePositionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: liquidity,
            amount0Min:0,
            amount1Min: 0,
            deadline: block.timestamp + 10000
            })
        );

    }

    function _reuseOldPosition(uint256 tokenId, address uniswapPoolAddr, BuyRentalParams memory params) private {
        UniswapNonFungiblePositionManager.increaseLiquidity(
           INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min,
            deadline: params.deadline
            })
        );

        getOldPositions[uniswapPoolAddr][params.tickLower][params.tickUpper] = 0;

    } 


    function collectFeesForCurrentRenter(uint256 tokenId) external override returns (uint256 token0amt, uint256 token1amt) {
        RentInfo memory rentInfo = tokenIdToRentInfo[tokenId];
        require(block.timestamp < rentInfo.expiryDate, "the lease has expired!");
        require(msg.sender == rentInfo.renter, "you are not renting this asset!");
         (token0amt, token1amt) = UniswapNonFungiblePositionManager.collect(INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: rentInfo.renter,
            amount0Max: 1000000000000,
            amount1Max: 1000000000000
         }));


    }









}