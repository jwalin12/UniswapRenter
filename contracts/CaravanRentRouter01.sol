pragma solidity =0.7.6;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import './interfaces/IBlackScholes.sol';
import './OptionGreekCache.sol';

import '@uniswap/v2-core/contracts/interfaces/IRentPoolFactory.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/IRentRouter01.sol';
import './libraries/UniswapV2Library.sol';
import './libraries/SafeMath.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './interfaces/IWETH.sol';

contract UniswapV2Router02 is IRentRouter01 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;

    OptionGreekCache private immutable optionGreekCache = OptionGreekCache('someaddresshere');


    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'RentRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function getRentalPrice(int24 tickUpper, int24 tickLower, uint256 duration, address poolAddr) external returns uint256 {
        IUniswapV3Pool memory UniswapPool =  IUniswapV3Pool(poolAddr);
        int56[] ticks = UniswapPool.observe([1, 0])[0];
        int56 tokenAPrice = TickMath.getSqrtRatioAtTick(ticks[1] - ticks[0]); //sqrt of the ratio of the two assets (token1/token0)
        
        if (spotPrice > midPrice) {
            IBlackScholes.PricesDeltaStdVega memory optionPrices =
                blackScholes.pricesDeltaStdVega(
                duration,
                optionGreekCache.getVol(poolAddr),
                tokenAPrice,
                TickMath.getSqrtRatioAtTick(tickUpper),
                optionGreekCache.getRiskFreeRate()
            ); // [<call price> , <put price> , <call delta> , <put delta> ] everything is in decimals            
            return optionPrices[1];
        } else {
            IBlackScholes.PricesDeltaStdVega memory optionPrices =
                blackScholes.pricesDeltaStdVega(
                duration,
                optionGreekCache.getVol(poolAddr),,
                tokenAPrice,
                TickMath.getSqrtRatioAtTick(tickLower),
                optionGreekCache.getRiskFreeRate()
            ); // [<call price> , <put price> , <call delta> , <put delta> ] everything is in decimals            
            return optionPrices[0];
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
        //who is the owner of these rentals?
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
        address to
    ) external virtual override returns (uint liquidity) {
        _addLiquidity(token, amount);
        address pool = IRentPoolFactory(factory).getPool(token);
        TransferHelper.safeTransferFrom(token, msg.sender, pool, amount);
        liquidity = IRentPool(pool).mint(to);
    }
    function addLiquidityETH(
        uint amountETH,
        address to
    ) external virtual override payable ensure(deadline) returns (uint liquidity) {
        _addLiquidity(WETH, msg.value);
        address pool = IRentPoolFactory(factory).getPool(token);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IRentPool(pool).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address token,
        uint amount,
        address to,
    ) public virtual override {
        address pool = IRentPoolFactory(factory).getPool(token);
        IRentPool(pool).transferFrom(msg.sender, pool, amount); // send liquidity to pair
        IRentPool(pool).burn(to);

    }
    function removeLiquidityETH(
        uint amountETH,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
<<<<<<< HEAD
        TransferHelper.safeTransfer(token, to, amountToken);
=======
        address pool = IRentPoolFactory(factory).getPool(token);
        IRentPool(pool).transferFrom(msg.sender, pool, amount); // send liquidity to pair
        IRentPool(pool).burn(to);
>>>>>>> 328f70231b15e56ad71e45e323e0ef746626fc5e
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }


    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}