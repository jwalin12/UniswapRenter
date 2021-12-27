pragma solidity =0.7.6;
pragma abicoder v2;

import "./interfaces/IRentPoolFactory.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import "./libraries/TickMath.sol";

import './interfaces/IRentRouter01.sol';
import './interfaces/IBlackScholes.sol';
import './interfaces/IRentPool.sol';
import './interfaces/IRentERC20.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './interfaces/IWETH.sol';
import './OptionGreekCache.sol';
import './BlackScholes.sol';

contract CaravanRentRouter01 is IRentRouter01 {
    using SafeMath for uint;

    address public immutable factory;
    address public immutable WETH;

    OptionGreekCache private immutable optionGreekCache;
    BlackScholes private immutable blackScholes;
    uint32[] private observationRange;

    struct PriceInfo {
        IUniswapV3Pool uniswapPool;
        uint160 tokenAPrice;
        uint160 sqrtRatioLower;
        uint160 sqrtRatioUpper;
        uint160 sqrtRatioMid;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'RentRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH, address optionGreekCacheAddress, address blackScholesAddress) public {
        factory = _factory;
        WETH = _WETH;
        observationRange.push(0);
        observationRange.push(1);
        optionGreekCache = OptionGreekCache(optionGreekCacheAddress);
        blackScholes = BlackScholes(blackScholesAddress);
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function getRentalPrice(int24 tickUpper, int24 tickLower, uint256 duration, address poolAddr) external returns (uint256) {
        PriceInfo memory price;
        price.uniswapPool =  IUniswapV3Pool(poolAddr);
        (int56[] memory ticks,) = price.uniswapPool.observe(observationRange);
        //ticks[1] and ticks[0] are int56
        price.tokenAPrice = TickMath.getSqrtRatioAtTick(ticks[1] - ticks[0]); //sqrt of the ratio of the two assets (token1/token0)
        price.sqrtRatioLower = TickMath.getSqrtRatioAtTick(tickLower); //sqrt of the ratio of the two assets (token1/token0)
        price.sqrtRatioUpper = TickMath.getSqrtRatioAtTick(tickUpper);
        price.sqrtRatioMid = price.sqrtRatioLower + (price.sqrtRatioLower + price.sqrtRatioUpper) / 2;
        //the mid price is wrong. It must be calculated using the squared ratios, not the sqrts.

        if (price.tokenAPrice > price.sqrtRatioMid) {
            IBlackScholes.PricesDeltaStdVega memory optionPrices =
                blackScholes.pricesDeltaStdVega(
                duration,
                optionGreekCache.getVol(poolAddr),
                price.tokenAPrice,
                price.sqrtRatioUpper,
                optionGreekCache.getRiskFreeRate()
            ); // [<call price> , <put price> , <call delta> , <put delta> ] everything is in decimals            
            return optionPrices.putPrice;
        } else {
            IBlackScholes.PricesDeltaStdVega memory optionPrices =
                blackScholes.pricesDeltaStdVega(
                duration,
                optionGreekCache.getVol(poolAddr),
                price.tokenAPrice,
                price.sqrtRatioLower,
                optionGreekCache.getRiskFreeRate()
            ); // [<call price> , <put price> , <call delta> , <put delta> ] everything is in decimals            
            return optionPrices.callPrice;
        }
        //instantiate uniswap v3 pool
        //instantiate BlackScholes
        //call observe to pool twice to get 2 tick readings
        //do math to get TWAP based on tick readings
        //if TWAP > mid of position range, call BlackScholes put with strike price as upper tick 
        //else call BlackScholes call with strike price as lower tick
        //return whatever BlackScholes did
    }

    function buyRentalListing() external payable {
        //check if enough liquidity is in the pool
        //check if price is right (call get price) and compare to slippage tolerance
        //create rental on existing rent platform
        //who is the owner of these rentals? managerial contract that we can collect fees from? or rent platform contract which could do the same.
        //rent platform handles everything with rentals and owns all pool rentals
        //when interacting with pool, use functions in this router
    }
    
    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address token,
        uint amount
    ) internal virtual {
        // create the pair if it doesn't exist yet
        if (IRentPoolFactory(factory).getPool(token) == address(0)) {
            IRentPoolFactory(factory).createPool(token);
        }
    }
    function addLiquidity(
        address token,
        uint amount,
        uint amountMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint liquidity) {
        _addLiquidity(token, amount);
        address pool = IRentPoolFactory(factory).getPool(token);
        TransferHelper.safeTransferFrom(token, msg.sender, pool, amount);
        liquidity = IRentPool(pool).mint(to);
        require(liquidity >= amountMin, "INSUFFICIENT LIQUIDITY MINTED");
    }

    function addLiquidityETH(
        uint amountETH,
        uint amountMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint liquidity) {
        _addLiquidity(WETH, msg.value);
        address pool = IRentPoolFactory(factory).getPool(WETH);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pool, amountETH));
        liquidity = IRentPool(pool).mint(to);
        require(liquidity >= amountMin, "INSUFFICIENT LIQUIDITY MINTED");
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }


    function withdrawFeesWithoutRemovingLiquidity(address token, uint feesMin, address to, uint deadline) ensure(deadline) override external returns (uint256 feesRecieved) {
        address pool = IRentPoolFactory(factory).getPool(token);
        feesRecieved = IRentPool(pool).withdrawFees(to);
        require(feesRecieved >= feesMin, "INSUFFICIENT FEES RECIEVED");

    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address token,
        uint amount,
        uint amountMin,
        uint feesMin,
        address to, 
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountTokensRecieved, uint feesRecieved) {
        address pool = IRentPoolFactory(factory).getPool(token);
        IRentERC20(pool).transferFrom(msg.sender, pool, amount); // send liquidity to pair
        (amountTokensRecieved, feesRecieved) = IRentPool(pool).burn(to);
        require(amountTokensRecieved >= amountMin, "INSUFFICIENT LIQUIDITY BURNED");
        require(feesRecieved >= feesMin, "INSUFFICIENT FEES RECIEVED");
    }
    function removeLiquidityETH(
        uint amountETH,
        uint amountMin,
        uint feesMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountTokensRecieved, uint feesRecieved) {
        removeLiquidity(
            WETH,
            amountETH,
            amountMin,
            feesMin,
            address(this),
            deadline
        );
        address pool = IRentPoolFactory(factory).getPool(WETH);
        IRentERC20(pool).transferFrom(msg.sender, pool, amountETH); // send liquidity to pair
       (uint amountRecieved, uint feesRecieved) = IRentPool(pool).burn(to);
        require(amountRecieved >= amountMin, "INSUFFICIENT LIQUIDITY BURNED");
        require(feesRecieved >= feesMin, "INSUFFICIENT FEES RECIEVED");

        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address token,
        uint amount,
        uint amountMin,
        uint feesMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountTokensRecieved, uint feesRecieved) {
        address pool = IRentPoolFactory(factory).getPool(token);
        uint value = approveMax ? uint(-1) : amount;
        IRentERC20(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountTokensRecieved, feesRecieved) = removeLiquidity(token, amount, amountMin, feesMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint amount,
        uint amountETHMin,
        uint feesMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountTokensRecieved, uint feesRecieved) {
        address pool = IRentPoolFactory(factory).getPool(token);
        uint value = approveMax ? uint(-1) : amount;
        IRentERC20(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        (uint amountTokensRecieved, uint feesRecieved) = removeLiquidityETH(amount, amountETHMin, feesMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        uint amount,
        uint amountMin,
        uint amountFeesMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            WETH,
            amount,
            amountMin,
            amountFeesMin,
            address(this),
            deadline
        );
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        uint amount,
        uint amountMin,
        uint amountFeesMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pool = IRentPoolFactory(factory).getPool(WETH);
        uint value = approveMax ? uint(-1) : amount;
        IRentERC20(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            amount, amountMin, amountFeesMin, to, deadline
        );
    }

}