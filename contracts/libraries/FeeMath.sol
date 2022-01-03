pragma solidity = 0.7.6;
// a library for protocol fee related calculations

import "../interfaces/IRentPoolFactory.sol";
import "../interfaces/IRentPool.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";





library FeeMath {
    /// @dev Internally this library uses 27 decimals of precision
  uint private constant PRECISE_UNIT = 1e27;




    function calculateFeeSplit(IRentPool pool0, IRentPool pool1, uint256 amount0, uint256 amount1, uint256 fee) public returns (uint256 token0Fee, uint256 token1Fee) {

        (uint256 totalAmountToken0, , ) = pool0.getReserves();
        (uint256 totalAmountToken1, , ) = pool1.getReserves();

        uint token1Ratio = (amount1/totalAmountToken1) * 1e27;
        uint token0Ratio = (amount0/totalAmountToken0) * 1e27;

        uint denom = token1Ratio + token0Ratio;

        token0Fee = (token0Ratio/denom) * fee;
        token1Fee = (token1Ratio/denom) * fee;




    }



}