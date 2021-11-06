 // SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/base/Multicall.sol";

import "utils/structs/tokenAddresses.sol";

/// @title NFT positions
/// @notice Wraps Uniswap V3 positions in the ERC721 non-fungible token interface
contract OptionPlatform is
    Multicall,
    IERC721Receiver
{
    INonfungiblePositionManager public immutable UniswapNFTManager =  INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

  struct OptionInfo {
        address payable currentOwner;
        address tokenLong;
        address paymentToken;
        uint256 tokenId;
        uint256 price;
        uint256 expiryDate;
    } 


    mapping(uint256 => OptionInfo) public itemIdToOptionInfo;
    mapping(uint256 => uint256) private itemIdToIndex;
    mapping(uint256 => bool) private itemIdForSale;
    mapping(uint256 => TokenAddresses) public itemIdToTokenAddrs;
    uint256[] public itemIds;
    uint256 public marketplaceFee; /// fee taken from seller, where a 1.26% fee is represented as 126. Calculate fee by doing price * marketplaceFee / 10,000
    address public _owner;

    constructor(address payable currOwner, uint256 fee) {
        _owner = currOwner;
        marketplaceFee = fee;
    }


    /**
    Sets owner of new smart contract.
     */
    function setOwner(address payable newOwner) public {
        require(msg.sender == _owner, "Unauthorized action");
        _owner = newOwner;
    }

    function changeFee(uint256 fee) public {
        require(msg.sender == _owner, "Unauthorized action");
        marketplaceFee = fee;
    }

    /**
    Returns array of all item Ids
     */
    function getAllItemIds() external view returns (uint256[] memory) {
        return itemIds;
    }

    //function that receives an NFT from an external source.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
    Caches token Addresses on chain */
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


    //price is in the units of the currency that the seller is being paid in. The opposite of the currency to long.
    function createLongOption(uint256 tokenId, uint256 price, uint256 duration, address tokenToLong) external {
        UniswapNFTManager.safeTransferFrom(msg.sender, address(this), tokenId);
        cacheTokenAddrs(tokenId);
        itemIds.push(tokenId);
        itemIdToIndex[tokenId] = itemIds.length - 1;
        TokenAddresses memory tokenAddrs = itemIdToTokenAddrs[tokenId];
        address tokenToPayIn;
        require(tokenToLong == tokenAddrs.token0Addr || tokenToLong == tokenAddrs.token1Addr, "token to long is not in the position");
        if (tokenToLong == tokenAddrs.token0Addr) {
            tokenToPayIn = tokenAddrs.token1Addr;
        } else if (tokenToLong == tokenAddrs.token1Addr) {
            tokenToPayIn = tokenAddrs.token0Addr;
        } 
        itemIdToOptionInfo[tokenId] = OptionInfo({
            tokenId: tokenId,
            currentOwner: msg.sender,
            price: price,
            expiryDate: block.timestamp + duration,
            tokenLong: tokenToLong,
            paymentToken: tokenToPayIn
        });

    }

    function putUpOptionForSale(uint256 tokenId) public {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(msg.sender == optionInfo.currentOwner, "you are not the owner!");
        itemIdForSale[tokenId] = true;
    }

    function removeOptionForSale(uint256 tokenId) public {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(msg.sender == optionInfo.currentOwner, "you are not the owner!");
        itemIdForSale[tokenId] = false;
    }



    function changeOptionPrice(uint256 tokenId, uint256 newPrice) external {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(msg.sender == optionInfo.currentOwner, "you are not the owner!");
        itemIdToOptionInfo[tokenId] = OptionInfo({
            tokenId: tokenId,
            currentOwner: optionInfo.currentOwner,
            price: newPrice,
            expiryDate: optionInfo.expiryDate,
            tokenLong: optionInfo.tokenLong,
            paymentToken: optionInfo.paymentToken
        });
    }


    function buyOption(uint256 tokenId) payable external{
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(itemIdForSale[tokenId], "this option is not for sale!");
        require(msg.sender != optionInfo.currentOwner, "you already own this option!");
        require(block.timestamp <= optionInfo.expiryDate, "option has already expired!");
        ERC20(optionInfo.paymentToken).transferFrom(msg.sender, optionInfo.currentOwner, optionInfo.price);
        itemIdToOptionInfo[tokenId] = OptionInfo({
            tokenId: tokenId,
            currentOwner: msg.sender,
            price: optionInfo.price,
            expiryDate: optionInfo.expiryDate,
            tokenLong: optionInfo.tokenLong,
            paymentToken: optionInfo.paymentToken
        });
        itemIdForSale[tokenId] = false;


    }

    function excersizeOption(uint256 tokenId) public {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(msg.sender == optionInfo.currentOwner, "you are not the owner!");
        UniswapNFTManager.safeTransferFrom(msg.sender, optionInfo.currentOwner, tokenId);
        removeItem(tokenId);

    }


    /**
    Deposits money in smart contract. used to collect fees. */
    function deposit(uint256 amount) public payable {
        require(msg.value == amount, "Insufficient funds");
    }

    /**
    Withdraws money from smart contract. */
    function withdraw() public {
        require(msg.sender == _owner, "You are not the owner!");
        msg.sender.transfer(address(this).balance);
    }
    

    //utility function that pays out NFT to receiver.
    function payoutNFT(uint256 tokenId, address payoutReceiver) private {      
        (uint256 token0amt, uint256 token1amt) = UniswapNFTManager.collect(INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: payoutReceiver,
            amount0Max: 1000000000,
            amount1Max: 1000000000
         }));
          
    }

    //Withdraw fees earned from rented NFT
    function withdrawFees(uint256 tokenId) external {
        //needs to check that time to rent has not passed
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(block.timestamp < optionInfo.expiryDate, "the option has expired!");
        require(msg.sender == optionInfo.currentOwner, "you do not own this option!");
        //call collect and send back to renter
        payoutNFT(tokenId, optionInfo.currentOwner);   
    }


    function removeItem(uint256 tokenId) private {
        delete(itemIdToOptionInfo[tokenId]);
        delete(itemIdForSale[tokenId]);
        if (itemIds.length > 1) {
            itemIdToIndex[itemIds[itemIds.length - 1]] = itemIdToIndex[tokenId];
            itemIds[itemIdToIndex[tokenId]] = itemIds[itemIds.length - 1]; 
        }
        itemIds.pop();
        delete(itemIdToIndex[tokenId]);
    }
}