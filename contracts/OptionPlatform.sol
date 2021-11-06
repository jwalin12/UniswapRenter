 // SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";


import "utils/structs/tokenAddresses.sol";

/// @title NFT positions
/// @notice Wraps Uniswap V3 positions in the ERC721 non-fungible token interface
contract OptionPlatform is
    Multicall,
    IERC721Receiver
{
    INonfungiblePositionManager public immutable UniswapNFTManager =  INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

  struct OptionInfo {
        address payable originalOwner;
        address payable currentOwner;
        address tokenLong;
        address paymentToken;
        uint256 tokenId;
        uint160 costToexcersize; 
        uint256 premium; // in ETH
        uint256 expiryDate;
        bool forSale;
    } 

    mapping(uint256 => OptionInfo) public itemIdToOptionInfo;
    mapping(uint256 => uint256) private itemIdToIndex;
    mapping(uint256 => TokenAddresses) public itemIdToTokenAddrs;
    mapping(address => uint256) tokenBalances;
    uint256[] public itemIds;
    uint256 public marketplaceFee; /// fee taken from seller, where a 1.26% fee is represented as 126. Calculate fee by doing premium * marketplaceFee / 10,000
    address public _owner;
    address[] tokens;
    mapping(address=> bool) tokensExist;

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
        if (!tokensExist[token0]) {
            tokens.push(token0);
            tokensExist[token0] = true;

        }
        if (!tokensExist[token1]){
            tokens.push(token1);
            tokensExist[token1] = true;
        }
        
        
        itemIdToTokenAddrs[tokenId] = TokenAddresses({ token0Addr: token0, token1Addr: token1 });
        
    }



    //For now we will use the lower end of the price range
    function getExcersizePrice(uint256 tokenId, address tokenLong) private returns (uint160) {

         (
            ,
            ,
            address token0,
            address token1,
            ,
            int24 tickLower,
            ,
            uint128 liquidity,
            ,
            ,
            ,
           
        ) = UniswapNFTManager.positions(tokenId);

    
    
        
    uint160 sqrtRatio = TickMath.getSqrtRatioAtTick(tickLower); //sqrt of the ratio of the two assets (token1/token0)

    if (token0 == tokenLong) {
        //if you are longing token0 you want amt in terms of token1.
        return sqrtRatio * liquidity;
        }
    if (token0 == tokenLong) {
        //if you are longing token1 the price is the amount of token0s if you are fully in token0
        return (1/sqrtRatio) * liquidity;
        }
        return 0;
    }


    //premium is in the units of the currency that the seller is being paid in. The opposite of the currency to long.
    function createLongOption(uint256 tokenId, uint256 premium, uint256 duration, address tokenLong) external {
        UniswapNFTManager.safeTransferFrom(msg.sender, address(this), tokenId);
        //cacheTokenAddrs(tokenId);
        // itemIds.push(tokenId);
        // itemIdToIndex[tokenId] = itemIds.length - 1;
        // TokenAddresses memory tokenAddrs = itemIdToTokenAddrs[tokenId];
        // address tokenToPayIn = address(0);
        // require(tokenLong == tokenAddrs.token0Addr || tokenLong == tokenAddrs.token1Addr, "token to long is not in the position");
        // if (tokenLong == tokenAddrs.token0Addr) {
        //     tokenToPayIn = tokenAddrs.token1Addr;
        // } else if (tokenLong == tokenAddrs.token1Addr) {
        //     tokenToPayIn = tokenAddrs.token0Addr;
        // } else {
        //     tokenToPayIn = address(0);
        // }

        //uint160 excersizePrice = getExcersizePrice(tokenId, tokenLong);

        // itemIdToOptionInfo[tokenId] = OptionInfo({
        //     originalOwner: msg.sender,
        //     tokenId: tokenId,
        //     currentOwner: msg.sender,
        //     premium: premium,
        //     expiryDate: block.timestamp + duration,
        //     costToexcersize: 0,
        //     tokenLong: tokenLong,
        //     paymentToken: tokenToPayIn,
        //     forSale: true
        // });

    }

    function putUpOptionForSale(uint256 tokenId) public {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(msg.sender == optionInfo.currentOwner, "you are not the owner!");
        itemIdToOptionInfo[tokenId].forSale = true;
    }

    function removeOptionForSale(uint256 tokenId) public {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(msg.sender == optionInfo.currentOwner, "you are not the owner!");
        itemIdToOptionInfo[tokenId].forSale = false;
    }



    function changeOptionPremium(uint256 tokenId, uint256 newpremium) external {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(msg.sender == optionInfo.currentOwner, "you are not the owner!");
        itemIdToOptionInfo[tokenId] = OptionInfo({
            tokenId: tokenId,
            currentOwner: optionInfo.currentOwner,
            originalOwner: optionInfo.originalOwner,
            premium: newpremium,
            expiryDate: optionInfo.expiryDate,
            tokenLong: optionInfo.tokenLong,
            costToexcersize: optionInfo.costToexcersize,
            paymentToken: optionInfo.paymentToken,
            forSale: optionInfo.forSale
        });
    }


    function buyOption(uint256 tokenId) payable external {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(optionInfo.forSale, "this option is not for sale!");
        require(msg.sender != optionInfo.currentOwner, "you already own this option!");
        require(block.timestamp <= optionInfo.expiryDate, "option has already expired!");
        require(msg.value == optionInfo.premium, "not enough funds!");
        itemIdToOptionInfo[tokenId].currentOwner.transfer(optionInfo.premium - optionInfo.premium * marketplaceFee / 10000);
        itemIdToOptionInfo[tokenId] = OptionInfo({
            tokenId: tokenId,
            currentOwner: msg.sender,
            premium: optionInfo.premium,
            originalOwner: optionInfo.originalOwner,
            expiryDate: optionInfo.expiryDate,
            tokenLong: optionInfo.tokenLong,
            costToexcersize: optionInfo.costToexcersize,
            paymentToken: optionInfo.paymentToken,
            forSale: false
        });


    }

    function excersizeOption(uint256 tokenId) public {
        OptionInfo memory optionInfo = itemIdToOptionInfo[tokenId];
        require(msg.sender == optionInfo.currentOwner, "you are not the owner!");
        ERC20(optionInfo.paymentToken).transferFrom(msg.sender, optionInfo.originalOwner, optionInfo.costToexcersize - optionInfo.costToexcersize * marketplaceFee / 10000);
        ERC20(optionInfo.paymentToken).transferFrom(msg.sender, address(this), optionInfo.costToexcersize * marketplaceFee / 10000);
        UniswapNFTManager.safeTransferFrom(address(this), optionInfo.currentOwner, tokenId);
        tokenBalances[optionInfo.paymentToken] = optionInfo.costToexcersize * marketplaceFee / 10000;
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
    function withdrawAllTokens() public {
        require(msg.sender == _owner, "You are not the owner!");
        for(uint i = 0; i < tokens.length; i++) {
            address currToken = tokens[i];
            if (tokenBalances[currToken] > 0) {
                ERC20(currToken).transferFrom(address(this),_owner,tokenBalances[currToken]);
            }
            tokenBalances[currToken] = 0;
            
        }
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

    //Withdraw fees earned from position
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
        if (itemIds.length > 1) {
            itemIdToIndex[itemIds[itemIds.length - 1]] = itemIdToIndex[tokenId];
            itemIds[itemIdToIndex[tokenId]] = itemIds[itemIds.length - 1]; 
        }
        itemIds.pop();
        delete(itemIdToIndex[tokenId]);
    }
}