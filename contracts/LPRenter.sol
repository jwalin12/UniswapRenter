// // SPDX-License-Identifier: MIT
// pragma solidity =0.7.6;
// pragma abicoder v2;

// import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "contracts/NonfungiblePositionManager.sol";
// import "utils/structs/tokenAddresses.sol";



// /**
// A smart contract that handles the logic for renting Uniswap V3 Positions
//  */
// //TODO: Gelato integration
// contract LPRenter is IERC721Receiver, NonfungiblePositionManager{

    // mapping(uint256 => address) private itemIdToOriginalOwner;
    // mapping(uint256 => address) private itemIdToRenter;
    // mapping(address => uint256) private renterToCashFlow;
    // mapping(uint256 => uint256) private itemIdToExpiryDate;
    // mapping(uint256 => uint256) private itemIdToPrice;
    // mapping(uint256 => TokenAddresses) private itemIdToTokenAddrs;
    // mapping(uint256 => address) private itemIdToNFTAddrs;

//     //function that receives an NFT from an external source.
//     function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
//         return this.onERC721Received.selector;

//     }


//     //Owner places NFT inside contract until they remove it or get an agreement
//     function putUpNFTForRent(uint256 tokenId, uint256 price,uint256 expiryDate, address owner, address nftAddress) external {
//         itemIdToOriginalOwner[tokenId] = owner;
//         itemIdToPrice[tokenId] = price;
//         itemIdToExpiryDate[tokenId] = expiryDate;
//         Position calldata positionInfo = this.positions(tokenId);
//         itemIdToNFTAddrs[tokenId] = nftAddress;
//         itemIdToTokenAddrs[tokenId] = TokenAddresses({token0Addr: positionInfo[2], token1Addr: positionInfo[3]}); //the two token addresses returned from calling positions 
//         ERC721(itemIdToNFTAddrs[tokenId]).safeTransferFrom(owner, address(this), tokenId);
//     }

//     //Owner removes NFT from rent availability
//     function removeNFTForRent(uint256 tokenId) external {
//         ERC721(itemIdToNFTAddrs[tokenId]).safeTransferFrom(address(this), itemIdToOriginalOwner[tokenId], tokenId);
//     }

//     function payoutNFT(uint256 tokenId, address payoutReceiver) private {
//          //call collect to get amounts of different tokens and send back to owner
//         (uint256 token0amt, uint256 token1amt) = this.collect(tokenId);

//         //send payment back to original owner
//         address token0Addr = itemIdToTokenAddrs[tokenId].token0Addr;
//         address token1Addr = itemIdToTokenAddrs[tokenId].token1Addr;
//         address originalOwner = itemIdToOriginalOwner[tokenId];
        

//         token0Addr.transfer(originalOwner, token0amt);
//         token1Addr.transfer(originalOwner, token1amt);

//     }

//     //Rents NFT to person who provided money
//     function rentNFT(uint256 tokenId, uint256 price) external {
//         //check if price is enough
//         require(msg.value>= price, "Insufficient funds");

//         //update who the renter is
//         itemIdToRenter[tokenId] = msg.sender;
//         payoutNFT(tokenId, msg.sender);
//     }
//     //Withdraw Cashflow from rented NFT
//     function withdrawCash(uint256 tokenId) external {
//         //needs to check that time to rent has not passed
//         require(block.timestamp <= itemIdToExpiryDate[tokenId], "the lease has expired!");
//         require(msg.sender == itemIdToRenter[tokenId], "you are not renting this asset!");
//         //call collect and send back to renter
//         this.payoutNFT(tokenId, itemIdToRenter[tokenId]);
//     }

//     //returns NFT to original owner once original rent period is up
//     function returnNFTToOwner(uint256 tokenId) external {
//         //check that rent period is up
//         require(block.timestamp >= itemIdToExpiryDate[tokenId], "the lease has not expired yet!");
//         require(msg.sender == itemIdToOriginalOwner[tokenId], "you are not renting this asset!");
//         //return control to original owner
//         address owner = itemIdToOriginalOwner[tokenId];
//         ERC721(itemIdToNFTAddrs[tokenId]).safeTransferFrom(address(this), owner, tokenId);

//     }


// }

