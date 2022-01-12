pragma solidity >= 0.7.6;
pragma abicoder v2;

import "./interfaces/IRentPlatform.sol";
import "./interfaces/IAutomatedRentalEscrow.sol";
import "./interfaces/IRentPlatform.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import "hardhat/console.sol";


    


contract AutomatedRentPlatform is IRentPlatform  {

    address _owner;
    address _rentalEscrow;



    constructor(address owner) {
            _owner = owner;
        }

        function setRentalEscrow(address rentalEscrow) external {
            require(msg.sender == _owner, "UNAUTHORIZED ACTION");
            _rentalEscrow = rentalEscrow;
        }

        function changeOwner(address newOwner) external {
            require(msg.sender == _owner, "UNAUTHORIZED ACTION");
            _owner = newOwner;
        }

        function createNewRental(IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddr, address _renter) external override returns (uint256 tokenId,
            uint256 amount0, uint256 amount1) {
            console.log("creating new rental...");
            require(_rentalEscrow != address(0), "RENTAL ESCROW NOT SET");
            console.log("checking for old postions...");
            tokenId = IAutomatedRentalEscrow(_rentalEscrow).getOldPositions(uniswapPoolAddr, params.tickUpper, params.tickLower);
            if (tokenId != 0) {
                (amount0, amount1) = IAutomatedRentalEscrow(_rentalEscrow).reuseOldPosition(tokenId, uniswapPoolAddr, params);
            }

            else {
                console.log("minting new pos...");
                console.log(msg.sender);
                INonfungiblePositionManager posManager = INonfungiblePositionManager(IAutomatedRentalEscrow(_rentalEscrow).getUniswapPositionManager());
                TransferHelper.safeApprove(params.token0, address(posManager),  params.amount0Desired);
                TransferHelper.safeApprove(params.token1, address(posManager),  params.amount1Desired);
                INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
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
                });
                (tokenId, , amount0, amount1) = posManager.mint(mintParams);
                
                // TransferHelper.safeApprove(token, to, value);
                //(bool success, bytes memory result) = address(posManager).delegatecall(abi.encodeWithSignature("mint(MintParams calldata params)", mintParams));
                //console.log("minted pos", success);

                //require(success, "FAILED TO MINT NEW POS");
                //(tokenId, amount0, amount1) = abi.decode(result, (uint256, uint256, uint256));


            }
            rentalsInProgress.push(tokenId);
           IAutomatedRentalEscrow(_rentalEscrow).handleNewRental(tokenId, params,uniswapPoolAddr, _renter);
    }

    function endRental(uint256 tokenId) external override { 
        IAutomatedRentalEscrow(_rentalEscrow).handleExpiredRental(tokenId);
        removeRental(tokenId);
    }

    function collectFeesForRenter(uint256 tokenId, uint256 token0Min, uint256 token1Min) external override returns (uint256, uint256) {
        (uint256 token0Amt, uint256 token1Amt) = IAutomatedRentalEscrow(_rentalEscrow).collectFeesForCurrentRenter(tokenId);
        require(token0Amt >= token0Min && token1Amt >= token1Min, "NOT ENOUGH FEES COLLECTED");
        return (token0Amt, token1Amt);

    }

    function removeRental(uint256 tokenId) private {
        rentalsInProgress.pop();


    }

}