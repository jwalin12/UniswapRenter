import "remix_tests.sol";
import "../contracts/NonfungiblePositionManager.sol";

contract PositionManagerTest {

    NonFungiblePositionManager PositionMangerToTest;
    address owner = "0x652E3fA6353de83ac2b667368E75FEec05e9d5A9";

    function testPutUpNFTForRent() {
        uint256 tokenId = 7595;
        address poolAddr = 0x60594a405d53811d3bc4766596efd80fd545a270;
        NonfungiblePositionManager.connect(owner).putUpNFTForRent(tokenId,100, 1000, poolAddr);
        assert(NonfungiblePositionManager.itemIdToRentInfo[tokenId] == 
            RentInfo({
            tokenId: tokenId,
            originalOwner: msg.sender,
            price: 100,
            duration: 10000,
            expiryDate: 0,
            renter: address(0)
        }));
        NonfungiblePositionManager.connect(owner).removeNFTForRent(tokenId);
        assert(NonfungiblePositionManager.itemIdToRentInfo.size() == 0);
    };




}

