pragma solidity 0.7.6;
pragma abicoder v2;


import "./interfaces/IRentPlatform.sol";
import "./interfaces/IAutomatedRentalEscrow.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import "hardhat/console.sol";

contract AutomatedRentalEscrow is IAutomatedRentalEscrow {

    mapping(uint256 => IRentPlatform.RentInfo) public tokenIdToRentInfo;


    address public _automatedRentalPlatform;
    address public _owner;
    
    INonfungiblePositionManager public UniswapNonFungiblePositionManager; 

    mapping(address => mapping(int24 => mapping(int24 => uint256))) public oldPositions;

    constructor(address uniswapNFTPositionManagerAddress, address automatedRentalPlatform, address  owner) { 
        UniswapNonFungiblePositionManager = INonfungiblePositionManager(uniswapNFTPositionManagerAddress);
        console.log("POS MANAGER at init", address(UniswapNonFungiblePositionManager));
        _automatedRentalPlatform = automatedRentalPlatform;
        _owner = owner;
    
    }
    function getUniswapPositionManager() external override returns (address) {
        console.log("POS MANAGER at get",address(UniswapNonFungiblePositionManager));
        return address(UniswapNonFungiblePositionManager);
    }
    function getOldPositions(address uniswapPoolAddr, int24 tickUpper, int24 tickLower) external override returns (uint256 tokenId) {
        tokenId = oldPositions[uniswapPoolAddr][tickUpper][tickLower];
    }

    function setAutomatedRentalPlatform(address automatedRentalPlatform) external {
        require(msg.sender == _owner, "UNAUTHORIZED ACTION");
        _automatedRentalPlatform = automatedRentalPlatform;
    }

    function changeOwner(address newOwner) external {
            require(msg.sender == _owner, "UNAUTHORIZED ACTION");
            _owner = newOwner;
        }


    function handleNewRental(uint256 tokenId, IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddr, address _renter) external override {
        require(msg.sender == payable(_automatedRentalPlatform),"UNAUTHORIZED ACTION");
        tokenIdToRentInfo[tokenId] = IRentPlatform.RentInfo({
                originalOwner: payable(address(this)),
                renter: payable(_renter),
                tokenId: tokenId,
                expiryDate: block.timestamp + params.duration,
            
                uniswapPoolAddress: uniswapPoolAddr
            });

    }

    function handleExpiredRental(uint256 tokenId) external override {
        IRentPlatform.RentInfo memory rentInfo = tokenIdToRentInfo[tokenId];
        require(msg.sender == _automatedRentalPlatform, "UNAUTHORIZED RECLAMATION");
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

        oldPositions[rentInfo.uniswapPoolAddress][tickLower][tickUpper] = tokenId;

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


        //TODO: return liquidity to pools
        );

    }

    function reuseOldPosition(uint256 tokenId, address uniswapPoolAddr, IRentPlatform.BuyRentalParams memory params) external override returns(uint256 amount0, uint256 amount1) {
        ( ,amount0, amount1) = UniswapNonFungiblePositionManager.increaseLiquidity(
           INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min,
            deadline: params.deadline
            })
        );

        oldPositions[uniswapPoolAddr][params.tickLower][params.tickUpper] = 0;

    } 


    function collectFeesForCurrentRenter(uint256 tokenId) external override returns (uint256 token0amt, uint256 token1amt) {
        IRentPlatform.RentInfo memory rentInfo = tokenIdToRentInfo[tokenId];
        require(msg.sender == _automatedRentalPlatform, "UNAUTHORIZED RECLAMATION");
        require(block.timestamp < rentInfo.expiryDate, "the lease has expired!");
         (token0amt, token1amt) = UniswapNonFungiblePositionManager.collect(INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: rentInfo.renter,
            amount0Max: 1000000000000,
            amount1Max: 1000000000000
         }));



    }









}