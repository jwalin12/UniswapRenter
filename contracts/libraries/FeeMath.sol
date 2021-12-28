pragma solidity = 0.7.6;
// a library for protocol fee related calculations

import "../interfaces/IRentPoolFactory.sol";
import "../interfaces/IRentPool.sol";
import "./SafeMath.sol";


library FeeMath {
    using SafeMath for uint256;


    function calculateFeeSplit(IRentPoolFactory factory, address token0, address token1, uint256 amount0, uint256 amount1) public returns (uint256 token0Fee, uint256 token1Fee) {
        IRentPool pool0 = IRentPool(factory.getPool(token0));
        IRentPool pool1 = IRentPool(factory.getPool(token1));

        (uint256 totalAmountToken0, , ) = pool0.getReserves();
        (uint256 totalAmountToken1, , ) = pool1.getReserves();


        //TODO: will probably have to fix this

        uint256 ratio = (amount0/totalAmountToken0) * (totalAmountToken1/amount1) * 10**27;



        



    }



}