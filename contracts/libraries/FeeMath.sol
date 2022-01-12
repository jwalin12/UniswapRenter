pragma solidity = 0.7.6;
// a library for protocol fee related calculations

import "../interfaces/IRentPoolFactory.sol";
import "../interfaces/IRentPool.sol";
import "../synthetix/SafeDecimalMath.sol";
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import "hardhat/console.sol";





library FeeMath {
    /// @dev Internally this library uses 27 decimals of precision
  uint private constant PRECISE_UNIT = 1e27;
  using SafeDecimalMath for uint;




    function calculateFeeSplit(IRentPool pool0, IRentPool pool1, uint256 amount0, uint256 amount1, uint256 fee) public returns (uint256 token0Fee, uint256 token1Fee) {

        (uint256 totalAmountToken0, , ) = pool0.getReserves();
        (uint256 totalAmountToken1, , ) = pool1.getReserves();



        uint token1Ratio;
        uint token0Ratio;

        if (totalAmountToken0 == 0) {
          token0Ratio = PRECISE_UNIT;
        } else {
          token0Ratio = FullMath.mulDiv(PRECISE_UNIT, amount0,totalAmountToken0);
        }
        if (totalAmountToken1 == 0) {
          token1Ratio = PRECISE_UNIT;
        }  else {
          token1Ratio = FullMath.mulDiv(PRECISE_UNIT, amount1,totalAmountToken1);
        }
        
        uint denom = token1Ratio + token0Ratio;
        require(denom > 0, "EMPTY POSITION");
        token0Fee = FullMath.mulDiv(token0Ratio, fee, denom);
        token1Fee = FullMath.mulDiv(token1Ratio, fee, denom);



    }



}