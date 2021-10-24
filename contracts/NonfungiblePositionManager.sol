// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint128.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungibleTokenPositionDescriptor.sol';
import '@uniswap/v3-periphery/contracts/libraries/PositionKey.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
import '@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol';
import '@uniswap/v3-periphery/contracts/base/PeripheryImmutableState.sol';
import '@uniswap/v3-periphery/contracts/base/Multicall.sol';
import '@uniswap/v3-periphery/contracts/base/ERC721Permit.sol';
import '@uniswap/v3-periphery/contracts/base/PeripheryValidation.sol';
import '@uniswap/v3-periphery/contracts/base/SelfPermit.sol';
import '@uniswap/v3-periphery/contracts/base/PoolInitializer.sol';

import "utils/structs/tokenAddresses.sol";

/// @title NFT positions
/// @notice Wraps Uniswap V3 positions in the ERC721 non-fungible token interface
contract NonfungiblePositionManager is
    Multicall,
    PeripheryImmutableState,
    PoolInitializer,
    LiquidityManagement,
    PeripheryValidation,
    SelfPermit,
    IERC721Receiver
{
    // details about the uniswap position
    struct Position {
        // the nonce for permits
        uint96 nonce;
        // the address that is approved for spending this token
        address operator;
        // the ID of the pool with which this token is connected
        uint80 poolId;
        // the tick range of the position
        int24 tickLower;
        int24 tickUpper;
        // the liquidity of the position
        uint128 liquidity;
        // the fee growth of the aggregate position as of the last action on the individual position
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // how many uncollected tokens are owed to the position, as of the last computation
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    //struct for what uniswap nonFungible PositionManager returns 

    struct RentInfo {
        uint256 tokenId;
        address payable originalOwner;
        address payable renter;
        uint256 price;
        uint256 duration;
        uint256 expiryDate;
    }

    INonfungiblePositionManager public immutable UniswapNFTManager =  INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

//TODO: consolidate mappings into structs
//TODO: update mappings in functions
//TODO: figure out how to 
    mapping(uint256 => RentInfo) public itemIdToRentInfo;
    mapping(address => uint256) private renterToCashFlow;
    mapping(uint256 => TokenAddresses) public itemIdToTokenAddrs;
    mapping(uint256 => address) private itemIdToPoolAddrs;
    mapping(uint256 => uint256) private itemIdToIndex;
    uint256[] public itemIds;

    /// @dev IDs of pools assigned by this contract
    mapping(address => uint80) private _poolIds;

    /// @dev Pool keys by pool ID, to save on SSTOREs for position data
    mapping(uint80 => PoolAddress.PoolKey) private _poolIdToPoolKey;

    /// @dev The token ID position data
    mapping(uint256 => Position) public _positions;

    /// @dev The ID of the next token that will be minted. Skips 0
    uint176 private _nextId = 1;
    /// @dev The ID of the next pool that is used for the first time. Skips 0
    uint80 private _nextPoolId = 1;

    /// @dev The address of the token descriptor contract, which handles generating token URIs for position tokens
    address private immutable _tokenDescriptor;

    constructor(
        address _factory,
        address _WETH9,
        address _tokenDescriptor_
    ) PeripheryImmutableState(_factory, _WETH9) {
        _tokenDescriptor = _tokenDescriptor_;
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position memory position = _positions[tokenId];
        require(position.poolId != 0, 'Invalid token ID');
        PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        return (
            position.nonce,
            position.operator,
            poolKey.token0,
            poolKey.token1,
            poolKey.fee,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

    /// @dev Caches a pool key
    function cachePoolKey(address pool, PoolAddress.PoolKey memory poolKey) private returns (uint80 poolId) {
        poolId = _poolIds[pool];
        if (poolId == 0) {
            _poolIds[pool] = (poolId = _nextPoolId++);
            _poolIdToPoolKey[poolId] = poolKey;
        }
    }

    function getAllItemIds() public returns (uint256[] memory) {
        return itemIds;
    }

    //function that receives an NFT from an external source.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        return this.onERC721Received.selector;

    }


    function getPositionFromUniswap(uint256 tokenId) private returns (Position memory) {
       (uint96 nonce,
            ,
            ,
            ,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1)
         = UniswapNFTManager.positions(tokenId);
        return Position({
        nonce: nonce,
        operator: address(this),
        poolId: 0, 
        tickLower: tickLower,
        tickUpper: tickUpper, 
        liquidity: liquidity, 
        feeGrowthInside0LastX128: feeGrowthInside0LastX128,
        feeGrowthInside1LastX128: feeGrowthInside1LastX128,
        tokensOwed0: tokensOwed0,
        tokensOwed1: tokensOwed1 
        });

   

    }

    function getPoolIdForPositionFromUniswap(uint256 tokenId, address poolAddr) private returns (uint80) {
        (,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            ,
            ,
            ,
            ,
            )
         = UniswapNFTManager.positions(tokenId);
        uint80 poolId =
            cachePoolKey(
                poolAddr,
                PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee})
            );
        return poolId;
    }


    function getTokensForPositionFromUniswap(uint256 tokenId) private {
        (,
            ,
            address token0,
            address token1,
            uint256 fee,
            ,
            ,
            ,
            ,
            ,
            ,
            )
         = UniswapNFTManager.positions(tokenId);

         itemIdToTokenAddrs[tokenId] = TokenAddresses({ token0Addr: token0, token1Addr: token1 });

    }
    //Owner places NFT inside contract until they remove it or get an agreement
    //Added by Jwalin
    function putUpNFTForRent(uint256 tokenId, uint256 price,uint256 duration, address poolAddr) external {
        UniswapNFTManager.safeTransferFrom(msg.sender, address(this), tokenId);
        _positions[tokenId] = getPositionFromUniswap(tokenId);
        itemIdToPoolAddrs[tokenId] = poolAddr;
        itemIds.push(tokenId);
        getTokensForPositionFromUniswap(tokenId); //updates mapping 

        itemIdToRentInfo[tokenId] = RentInfo({
            tokenId: tokenId,
            originalOwner: msg.sender,
            price: price,
            duration: duration,
            expiryDate: 0,
            renter: address(0)
        });
    }

    //Owner removes NFT from rent availability
    //Added by Jwalin
    function removeNFTForRent(uint256 tokenId) external {
        RentInfo memory rentInfo = itemIdToRentInfo[tokenId];
        require(rentInfo.renter == address(0),"someone is renting right now!");
        require(rentInfo.originalOwner == msg.sender, "you do not own this NFT!");
        delete(itemIdToRentInfo[tokenId]);
        UniswapNFTManager.safeTransferFrom(address(this),rentInfo.originalOwner, tokenId);
        itemIdToIndex[itemIds.length - 1] = itemIdToIndex[tokenId];
        itemIds[itemIdToIndex[tokenId]] = itemIds[itemIds.length - 1]; 
        itemIds.pop();
    }

    //utility function that pays out NFT to receiver.
    //Added by Jwalin
    function payoutNFT(uint256 tokenId, address payoutReceiver) private {
         //call collect to get amounts of different tokens and send back to owner        
        (uint256 token0amt, uint256 token1amt) = this.collect(INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: payoutReceiver,
            amount0Max: 1000000000,
            amount1Max: 1000000000
         }));
        // //send payment back to original owner
        // address token0Addr = itemIdToTokenAddrs[tokenId].token0Addr;
        // address token1Addr = itemIdToTokenAddrs[tokenId].token1Addr;
        // if (token0amt > 0) {
        //     ERC20(token0Addr).transferFrom(address(this), payoutReceiver, token0amt);

        // }
        // if (token1amt > 0) {
        //     ERC20(token1Addr).transferFrom(address(this), payoutReceiver, token1amt);
        // }
       
        
    }

    //Rents NFT to person who provided money
    //Added by Jwalin
    function rentNFT(uint256 tokenId) external payable {
        //check if price is enough
        RentInfo memory rentInfo = itemIdToRentInfo[tokenId];
        require(msg.value >= rentInfo.price, "Insufficient funds");
        require(rentInfo.renter == address(0), "already being rented!");
        //update who the renter is
        itemIdToRentInfo[tokenId] = RentInfo({
            tokenId: tokenId,
            originalOwner: itemIdToRentInfo[tokenId].originalOwner,
            price: itemIdToRentInfo[tokenId].price,
            duration: itemIdToRentInfo[tokenId].duration,
            expiryDate: block.timestamp + itemIdToRentInfo[tokenId].duration,
            renter: msg.sender
        });
        itemIdToRentInfo[tokenId].originalOwner.transfer(itemIdToRentInfo[tokenId].price);
        // payoutNFT(tokenId, rentInfo.originalOwner);
        
    }

    //Withdraw Cashflow from rented NFT
    // Added by Jwalin
    function withdrawCash(uint256 tokenId) external {
        //needs to check that time to rent has not passed
        RentInfo memory rentInfo = itemIdToRentInfo[tokenId];
        require(block.timestamp < rentInfo.expiryDate, "the lease has expired!");
        require(msg.sender == rentInfo.renter, "you are not renting this asset!");
        //call collect and send back to renter
        payoutNFT(tokenId, rentInfo.renter);
        
    }

    //returns NFT to original owner once original rent period is up
    // Added by Jwalin
    function returnNFTToOwner(uint256 tokenId) external {
        //check that rent period is up
        RentInfo memory rentInfo = itemIdToRentInfo[tokenId];
        require(block.timestamp >= rentInfo.expiryDate, "the lease has not expired yet!");
        require(msg.sender == rentInfo.originalOwner, "you are not the original owner for this asset!");
        //return control to original owner
        address owner = rentInfo.originalOwner;
        itemIdToIndex[itemIds.length - 1] = itemIdToIndex[tokenId];
        itemIds[itemIdToIndex[tokenId]] = itemIds[itemIds.length - 1]; 
        itemIds.pop();
        UniswapNFTManager.safeTransferFrom(address(this), owner, tokenId);

    }
    function collect(INonfungiblePositionManager.CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1)
    {
        require(params.amount0Max > 0 || params.amount1Max > 0);
        // allow collecting to the nft position manager address with address 0
        address recipient = params.recipient == address(0) ? address(this) : params.recipient;

        Position storage position = _positions[params.tokenId];

        IUniswapV3Pool pool = IUniswapV3Pool(itemIdToPoolAddrs[params.tokenId]);

        (uint128 tokensOwed0, uint128 tokensOwed1) = (position.tokensOwed0, position.tokensOwed1);

        // trigger an update of the position fees owed and fee growth snapshots if it has any liquidity
        if (position.liquidity > 0) {
            pool.burn(position.tickLower, position.tickUpper, 0);
            (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, , ) =
                pool.positions(PositionKey.compute(address(this), position.tickLower, position.tickUpper));

            tokensOwed0 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - position.feeGrowthInside0LastX128,
                    position.liquidity,
                    FixedPoint128.Q128
                )
            );
            tokensOwed1 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - position.feeGrowthInside1LastX128,
                    position.liquidity,
                    FixedPoint128.Q128
                )
            );

            position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
            position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        }

        // compute the arguments to give to the pool#collect method
        (uint128 amount0Collect, uint128 amount1Collect) =
            (
                params.amount0Max > tokensOwed0 ? tokensOwed0 : params.amount0Max,
                params.amount1Max > tokensOwed1 ? tokensOwed1 : params.amount1Max
            );

        // the actual amounts collected are returned
        (amount0, amount1) = pool.collect(
            recipient,
            position.tickLower,
            position.tickUpper,
            amount0Collect,
            amount1Collect
        );

        // sometimes there will be a few less wei than expected due to rounding down in core, but we just subtract the full amount expected
        // instead of the actual amount so we can burn the token
        (position.tokensOwed0, position.tokensOwed1) = (tokensOwed0 - amount0Collect, tokensOwed1 - amount1Collect);

    }
}