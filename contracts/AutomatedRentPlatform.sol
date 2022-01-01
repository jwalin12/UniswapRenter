pragma solidty >= 0.7.6;
pragma abicoder v2;

import "./interfaces/IRentPlatform.sol";
import "./interfaces/IAutomatedRentalEscrow.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';


    


contract AutomatedRentPlatform {

    address _owner;
    address _rentalEscrow;



    constructor(address owner) {
            _owner = owner;
        }

        function setRentalEscrow(address rentalEscrow) external {
            _rentalEscrow = rentalEscrow;
        }

        function changeOwner(address newOwner) external {
            require(msg.sender == _owner, "UNAUTHORIZED ACTION");
            _owner = newOwner;
        }

        function createNewRental(IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddr, address _renter) external override {
            require(msg.sender == _owner, "UNAUTHORIZED ACTION");
            require(_rentalEscrow != address(0), "RENTAL ESCROW NOT SET");
            uint256 tokenId = IAutomatedRentalEscrow(_rentalEscrow).getOldPositions(uniswapPoolAddr, params.tickUpper, params.tickLower);
            if (tokenId != 0) {
                IAutomatedRentalEscrow(_rentalEscrow).reuseOldPosition(tokenId, uniswapPoolAddr, params);
            }

            else {
                (uint256 tokenID, , , ) = INonfungiblePositionManager(IAutomatedRentalEscrow(_rentalEscrow).UniswapNonFungiblePositionManager).mint(
                INonfungiblePositionManager.MintParams({
                token0: params.token0,
                token1: params.token1,
                fee: params.fee,
                recipient: _rentalEscrow,
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
           IAutomatedRentalEscrow(_rentalEscrow).handleNewRental(tokenId, params,uniswapPoolAddr, _renter);
    }

    function endRental(uint256 tokenId) external override { 
        IAutomatedRentalEscrow(_rentalEscrow).handleExpiredRental(tokenId);
    }

    function collectFeesForRenter(uint256 tokenId, uint256 token0Min, uint256 token1Min) external override {
        (uint256 token0Amt, uint256 token1Amt) = IAutomatedRentalEscrow(_rentalEscrow).collectFeesForCurrentRenter(tokenId);
        require(token0Amt >= token0Min && token1Amt >= token1Min, "NOT ENOUGH FEES COLLECTED");


    }

}