pragma solidity 0.7.6;
pragma abicoder v2;


import "./abstract/IRentPlatform.sol";
import "./abstract/IAutomatedRentalEscrow.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import "hardhat/console.sol";

contract AutomatedRentalEscrow is IAutomatedRentalEscrow {
    

    address public _automatedRentalPlatform;
    address public _owner;
    
    INonfungiblePositionManager public UniswapNonFungiblePositionManager; 

    mapping(address => mapping(int24 => mapping(int24 => uint256))) public oldPositions;//addr -> tick lower -> tick upper

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
    function getOldPositions(address uniswapPoolAddress, int24 tickUpper, int24 tickLower) external override returns (uint256 tokenId) {
        tokenId = oldPositions[uniswapPoolAddress][tickUpper][tickLower];
    }

    function setAutomatedRentalPlatform(address automatedRentalPlatform) external {
        require(msg.sender == _owner, "UNAUTHORIZED ACTION");
        _automatedRentalPlatform = automatedRentalPlatform;
    }

    function changeOwner(address newOwner) external {
            require(msg.sender == _owner, "UNAUTHORIZED ACTION");
            _owner = newOwner;
        }


    function handleNewRental(uint256 tokenId, IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddress, address _renter) external override {
        require(msg.sender == payable(_automatedRentalPlatform),"UNAUTHORIZED ACTION");
         tokenIdToRentInfo[tokenId] = IRentPlatform.RentInfo({
                originalOwner: payable(address(this)),
                renter: payable(_renter),
                tokenId: tokenId,
                expiryDate: block.timestamp + params.duration,
            
                uniswapPoolAddress: uniswapPoolAddress
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

    function handleReuseOldPosition(uint256 tokenId, address uniswapPoolAddress, IRentPlatform.BuyRentalParams memory params) external override returns(uint256 amount0, uint256 amount1) {
       oldPositions[uniswapPoolAddress][params.tickLower][params.tickUpper] = 0;

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