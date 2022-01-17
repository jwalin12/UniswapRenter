pragma solidity >= 0.7.6;
pragma abicoder v2;

import "./abstract/IRentPlatform.sol";
import "./abstract/IAutomatedRentalEscrow.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


    


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


        function useOldPosition(IRentPlatform.BuyRentalParams memory params, uint256 tokenId, address uniswapPoolAddr) private returns (uint256 amount0, uint256 amount1) {
            INonfungiblePositionManager posManager = INonfungiblePositionManager(IAutomatedRentalEscrow(_rentalEscrow).getUniswapPositionManager());
            IERC20(params.token0).approve(address(posManager), params.amount0Desired);
            IERC20(params.token1).approve(address(posManager), params.amount1Desired);

            ( ,amount0, amount1) = posManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                deadline: params.deadline
            })
        );
        IAutomatedRentalEscrow(_rentalEscrow).handleReuseOldPosition(tokenId,  uniswapPoolAddr, params);


        }

        function createNewRental(IRentPlatform.BuyRentalParams memory params, address uniswapPoolAddress, address _renter) external override returns (uint256 tokenId,
            uint256 amount0, uint256 amount1) {
            require(_rentalEscrow != address(0), "RENTAL ESCROW NOT SET");
            
            tokenId = IAutomatedRentalEscrow(_rentalEscrow).getOldPositions(uniswapPoolAddress, params.tickLower, params.tickUpper);
            if (tokenId != 0) {
                
                (amount0, amount1) = useOldPosition(params, tokenId, uniswapPoolAddress);
            }

            else {
                address posManagerAddress = IAutomatedRentalEscrow(_rentalEscrow).getUniswapPositionManager();
                TransferHelper.safeApprove(params.token0, posManagerAddress,  params.amount0Desired);
                TransferHelper.safeApprove(params.token1, posManagerAddress,  params.amount1Desired);

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
                (tokenId, ,amount0, amount1) = INonfungiblePositionManager(posManagerAddress).mint(mintParams);                
                // TransferHelper.safeApprove(token, to, value);
                //(bool success, bytes memory result) = address(posManager).delegatecall(abi.encodeWithSignature("mint(MintParams calldata params)", mintParams));
                //console.log("minted pos", success);

                //require(success, "FAILED TO MINT NEW POS");
                //(tokenId, amount0, amount1) = abi.decode(result, (uint256, uint256, uint256));


            }


            rentalsInProgress.push(tokenId);
           IAutomatedRentalEscrow(_rentalEscrow).handleNewRental(tokenId, params,uniswapPoolAddress, _renter);
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

    function getRentalInfoParams(uint256 tokenId) external override view returns (address payable, address payable,uint256, uint256, address) {
        return IAutomatedRentalEscrow(_rentalEscrow).tokenIdToRentInfo(tokenId);


    }

}