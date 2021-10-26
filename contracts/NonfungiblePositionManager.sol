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
    IERC721Receiver
{


    INonfungiblePositionManager public immutable UniswapNFTManager =  INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

//TODO: consolidate mappings into structs
//TODO: update mappings in functions
//TODO: figure out how to 

  struct RentInfo {
        uint256 tokenId;
        address payable originalOwner;
        address payable renter;
        uint256 price;
        uint256 duration;
        uint256 expiryDate;
    } 

    mapping(uint256 => RentInfo) public itemIdToRentInfo;
    mapping(uint256 => uint256) private itemIdToIndex;
    mapping(uint256 => TokenAddresses) public itemIdToTokenAddrs;
    uint256[] public itemIds;

    function getAllItemIds() public returns (uint256[] memory) {
        return itemIds;
    }

    //function that receives an NFT from an external source.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function cacheTokenAddrs(uint256 tokenId) private {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
           
        ) = UniswapNFTManager.positions(tokenId);
        itemIdToTokenAddrs[tokenId] = TokenAddresses({ token0Addr: token0, token1Addr: token1 });
        
    }


    //Owner places NFT inside contract until they remove it or get an agreement
    //Added by Jwalin
    //TODO: create a func that gets position Info and stores it in a mapping then lookup mapping for tokens and positions
    function putUpNFTForRent(uint256 tokenId, uint256 price,uint256 duration) external {
        UniswapNFTManager.safeTransferFrom(msg.sender, address(this), tokenId);
        itemIds.push(tokenId);
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
        (uint256 token0amt, uint256 token1amt) = UniswapNFTManager.collect(INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: 1000000000,
            amount1Max: 1000000000
         }));
        //send payment back to original owner
        address token0Addr = itemIdToTokenAddrs[tokenId].token0Addr;
        address token1Addr = itemIdToTokenAddrs[tokenId].token1Addr;
        if (token0amt > 0) {
            ERC20(token0Addr).transferFrom(address(this), payoutReceiver, token0amt);

        }
        if (token1amt > 0) {
            ERC20(token1Addr).transferFrom(address(this), payoutReceiver, token1amt);
        }
          
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
}