pragma solidity =0.7.6;
pragma abicoder v2;

import "./interfaces/IRentPoolFactory.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import "./abstract/IRentPlatform.sol";
import './interfaces/IRentRouter01.sol';
import './interfaces/IBlackScholes.sol';
import './interfaces/IRentPool.sol';
import './interfaces/IRentPoolFactory.sol';
import './interfaces/IRentERC20.sol';
import "./libraries/FeeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './interfaces/IWETH.sol';
import './interfaces/IOptionGreekCache.sol';
import "./synthetix/SafeDecimalMath.sol";
import "./synthetix/SignedSafeDecimalMath.sol";
import "hardhat/console.sol";


contract CaravanRentRouter01 is IRentRouter01 {
    using SafeMath for uint;
    using SafeDecimalMath for uint;
    using SignedSafeMath for int;
    using SignedSafeDecimalMath for int;

    /// @dev Internally this library uses 27 decimals of precision
    uint private constant PRECISE_UNIT = 1e18;

    address public immutable factory;
    address public immutable WETH;

    IOptionGreekCache private immutable optionGreekCache;
    IBlackScholes private immutable blackScholes;
    IUniswapV3Factory private immutable uniswapV3Factory;
    IRentPlatform private immutable rentPlatform;
    uint32[] private observationRange = new uint32[](2);
    uint256 premiumFee; 
    address feeTo;
    address feeToSetter;

    struct PriceInfo {
        IUniswapV3Pool uniswapPool;
        uint token0Decimals;
        uint token1Decimals;
        uint tokenAPrice;
        uint ratioLower;
        uint ratioUpper;
        uint ratioMid;
        uint vol;
        int rate;
        uint call;
        uint put;
        int meanTick;
    }

    struct SqrtRatios {
        uint160 sqrtRatioX96;
        uint160 sqrtRatioUpperX96;
        uint160 sqrtRatioLowerX96;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'RentRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH, address optionGreekCacheAddress, address blackScholesAddress, address rentPlatformAddress, address uniswapV3FactoryAddress, address _feeTo, address _feeToSetter, uint256 _premiumFee) public {
        factory = _factory;
        WETH = _WETH;
        observationRange[0] = 10;
        observationRange[1] = 0;
        optionGreekCache = IOptionGreekCache(optionGreekCacheAddress);
        blackScholes = IBlackScholes(blackScholesAddress);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3FactoryAddress);
        rentPlatform = IRentPlatform(rentPlatformAddress);
        feeTo = _feeTo;
        feeToSetter = _feeToSetter;
        premiumFee = _premiumFee;

    }

    receive() external payable {
    }

    function setFeeTo(address to) external override  {
        require(msg.sender == feeToSetter, "UNAUTHORIZED");
        feeTo = to;
    }

    function setFeeToSetter(address to) external override  {
        require(msg.sender == feeToSetter, "UNAUTHORIZED");
        feeToSetter = to;
    }

    function setFee(uint256 newFee) external override {
        require(msg.sender == feeToSetter, "UNAUTHORIZED");
        require(newFee >= 0, "INVALID FEE");
        premiumFee = newFee;

    }

    function sqrtRatioToRatio(uint160 sqrtRatioX96, uint128 baseAmount, address baseToken, address quoteToken) internal pure returns (uint256 quoteAmount) {
        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }


    function test(int24 tickUpper, int24 tickLower, uint256 durationInSeconds, address poolAddr, uint256 amountToken0, uint256 amountToken1) public view returns (PriceInfo memory) {
        PriceInfo memory price;
        price.uniswapPool = IUniswapV3Pool(poolAddr);
        (int24 meanTick, ) = OracleLibrary.consult(poolAddr, 60);
        price.meanTick = meanTick;
        price.token0Decimals = 10**IRentERC20(price.uniswapPool.token0()).decimals();
        price.token1Decimals = 10**IRentERC20(price.uniswapPool.token1()).decimals();
        //getQuoteAtTick returns token1/token0 (price of token0 in terms of token1)
        price.tokenAPrice = OracleLibrary.getQuoteAtTick(meanTick, uint128(price.token0Decimals), price.uniswapPool.token0(), price.uniswapPool.token1()); 
        price.tokenAPrice = FullMath.mulDiv(PRECISE_UNIT, price.tokenAPrice, price.token1Decimals);
        price.ratioLower = OracleLibrary.getQuoteAtTick(tickLower, uint128(PRECISE_UNIT), price.uniswapPool.token0(), price.uniswapPool.token1()); 
        price.ratioUpper = OracleLibrary.getQuoteAtTick(tickUpper, uint128(PRECISE_UNIT), price.uniswapPool.token0(), price.uniswapPool.token1());
        price.ratioMid = (price.ratioLower >> 1) + (price.ratioUpper >> 1) + (price.ratioLower & price.ratioUpper & 1);
        price.vol = optionGreekCache.getVol(poolAddr);
        price.rate = optionGreekCache.getRiskFreeRate();
        if (price.ratioLower == 0) {
            price.ratioLower = 1;
        } 
        //real reserves: ( x_r + L / sqrt(p_b) ) * ( y_r + L * sqrt(p_a) ) = L^2
        
        // virtual reserves:
        // L = sqrt(x * y)
        // sqrt(p) = sqrt(y / x)
        // x = L / sqrt(p)
        // y = L * sqrt(p)
        // L = uint128 liquidity
        // sqrt(p) = uint160 sqrtPriceX96
        // 
        //if price is out of range below, all tokens should be token0
        if (price.tokenAPrice < price.ratioLower) {
            // do nothing, just ignore amountToken1
        }
        if (amountToken0 == 0) {
            amountToken0 = amountToken1.divideDecimalRound(price.tokenAPrice);
        }
        //option price is denominated in token1 and is scaled by amount of token0
        //since its denominated in token1, need to divide by token1 decimals to get actual number
        IBlackScholes.PricesDeltaStdVega memory optionPrices;
        if (price.tokenAPrice < price.ratioMid) {
            optionPrices = 
                blackScholes.pricesDeltaStdVega(
                    durationInSeconds,
                    optionGreekCache.getVol(poolAddr),
                    price.tokenAPrice,
                    price.ratioLower,
                    optionGreekCache.getRiskFreeRate()
                );
        } else {
            optionPrices = 
                blackScholes.pricesDeltaStdVega(
                    durationInSeconds,
                    optionGreekCache.getVol(poolAddr),
                    price.tokenAPrice,
                    price.ratioUpper,
                    optionGreekCache.getRiskFreeRate()
                );
        }
        price.call = FullMath.mulDiv(optionPrices.callPrice, amountToken0, price.token0Decimals);
        price.put = FullMath.mulDiv(optionPrices.putPrice, amountToken0, price.token0Decimals);
        return price;
    }    
   
    function getRentalPrice(SqrtRatios memory ratios, IRentPlatform.BuyRentalParams memory params, address poolAddr) public view returns (uint256) {
        //instantiate stuff
        uint256 amountToken0 = params.amount0Desired;
        uint256 amountToken1 = params.amount1Desired;


        PriceInfo memory price;        
        price.uniswapPool = IUniswapV3Pool(poolAddr);
        price.token0Decimals = 10**IRentERC20(price.uniswapPool.token0()).decimals();
        price.token1Decimals = 10**IRentERC20(price.uniswapPool.token1()).decimals();
        //calculate price of token1/token0 = price of token 0 in terms of token1
        //calculate price of upper and lower ticks and their mean
        price.tokenAPrice = sqrtRatioToRatio(ratios.sqrtRatioX96, uint128(price.token0Decimals), price.uniswapPool.token0(), price.uniswapPool.token1());
        price.tokenAPrice = FullMath.mulDiv(PRECISE_UNIT, price.tokenAPrice, price.token1Decimals);
        price.ratioLower = sqrtRatioToRatio(ratios.sqrtRatioLowerX96, uint128(PRECISE_UNIT), price.uniswapPool.token0(), price.uniswapPool.token1()); 
        price.ratioUpper = sqrtRatioToRatio(ratios.sqrtRatioUpperX96, uint128(PRECISE_UNIT), price.uniswapPool.token0(), price.uniswapPool.token1());
        price.ratioMid = (price.ratioLower >> 1) + (price.ratioUpper >> 1) + (price.ratioLower & price.ratioUpper & 1);
        
        if (price.tokenAPrice >= price.ratioLower && price.tokenAPrice <= price.ratioUpper) {
            amountToken0 += amountToken1.divideDecimalRound(price.tokenAPrice);
        }
        if (price.tokenAPrice >= price.ratioUpper) {
            amountToken0 = amountToken1.divideDecimalRound(price.tokenAPrice);
        }
        //option price is denominated in token1 and is scaled by amount of token0
        //since its denominated in token1, need to divide by token1 decimals to get actual number
        //and need to multiply by price of token1 in USD to get rental price in USD
        //since price is per unit (of token0), need to scale by amount of token0 to get total price
        //depending on whether ratio of token1/token0 is above mid or below mid, price as a call or a put
        IBlackScholes.PricesDeltaStdVega memory optionPrices;
        if (price.tokenAPrice < price.ratioMid) {
            optionPrices = 
                blackScholes.pricesDeltaStdVega(
                    params.duration,
                    optionGreekCache.getVol(poolAddr),
                    price.tokenAPrice,
                    price.ratioLower,
                    optionGreekCache.getRiskFreeRate()
                );
            return FullMath.mulDiv(optionPrices.callPrice, amountToken0, price.token0Decimals);
        } else {
            optionPrices = 
                blackScholes.pricesDeltaStdVega(
                    params.duration,
                    optionGreekCache.getVol(poolAddr),
                    price.tokenAPrice,
                    price.ratioUpper,
                    optionGreekCache.getRiskFreeRate()
                );
            return FullMath.mulDiv(optionPrices.putPrice, amountToken0, price.token0Decimals);
        }
    }

    function getSqrtRatios(IRentPlatform.BuyRentalParams memory params, address poolAddr) public returns (SqrtRatios memory) {
        (uint160 sqrtRatioX96, , , , , , )  = IUniswapV3Pool(poolAddr).slot0();
        uint160 sqrtRatioLowerX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
        uint160 sqrtRatioUpperX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);
        return SqrtRatios ({
            sqrtRatioX96: sqrtRatioX96,
            sqrtRatioLowerX96: sqrtRatioLowerX96,
            sqrtRatioUpperX96: sqrtRatioUpperX96
        });

    }

    function quoteRental(IRentPlatform.BuyRentalParams memory params) public returns (uint256 rentalPrice) {
        //check if enough liquidity is in the pool
        // require(params.tickUpper > params.tickLower, "INCORRECT TICKS");
        // require(block.timestamp < params.deadline, "DEADLINE PASSED");
        //check if price is right (call get price) and compare to slippage tolerance
        //create rental on existing rent platform
        console.log(msg.sender);
        address poolAddr = uniswapV3Factory.getPool(params.token0, params.token1, params.fee);
        // require(poolAddr != address(0), "UNISWAP POOL DOES NOT EXIST");
        SqrtRatios memory sqrtRatios = getSqrtRatios(params, poolAddr);
        
        //ticks must be within max and min tick. Could switch this to require if u want
        if (params.tickLower <= TickMath.MIN_TICK) {
            params.tickLower = TickMath.MIN_TICK;
        }
        if (params.tickUpper >= TickMath.MAX_TICK) {
            params.tickUpper = TickMath.MAX_TICK;
        }

        (params.amount0Desired, params.amount1Desired) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatios.sqrtRatioX96, sqrtRatios.sqrtRatioLowerX96, sqrtRatios.sqrtRatioUpperX96, LiquidityAmounts.getLiquidityForAmounts(sqrtRatios.sqrtRatioX96,  sqrtRatios.sqrtRatioLowerX96, sqrtRatios.sqrtRatioUpperX96, params.amount0Desired, params.amount1Desired));
        rentalPrice = getRentalPrice(sqrtRatios, params, poolAddr);
    }

    function buyRental(IRentPlatform.BuyRentalParams memory params) external payable {
        IRentPoolFactory rentPoolFactory = IRentPoolFactory(factory);
        
        //check if enough liquidity is in the pool
        IRentPool pool0 =  IRentPool(rentPoolFactory.getPool(params.token0));
        IRentPool pool1 =  IRentPool(rentPoolFactory.getPool(params.token1));
        require(params.tickUpper > params.tickLower, "INCORRECT TICKS");
        require(block.timestamp < params.deadline, "DEADLINE PASSED");
        //check if price is right (call get price) and compare to slippage tolerance
        //create rental on existing rent platform
        address poolAddr = uniswapV3Factory.getPool(params.token0, params.token1, params.fee);
        require(poolAddr != address(0), "UNISWAP POOL DOES NOT EXIST");
        SqrtRatios memory sqrtRatios = getSqrtRatios(params, poolAddr);
        
        //ticks must be within max and min tick. Could switch this to require if u want
        if (params.tickLower <= TickMath.MIN_TICK) {
            params.tickLower = TickMath.MIN_TICK;
        }
        if (params.tickUpper >= TickMath.MAX_TICK) {
            params.tickUpper = TickMath.MAX_TICK;
        }

       (params.amount0Desired, params.amount1Desired) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatios.sqrtRatioX96, sqrtRatios.sqrtRatioLowerX96, sqrtRatios.sqrtRatioUpperX96, LiquidityAmounts.getLiquidityForAmounts(sqrtRatios.sqrtRatioX96,  sqrtRatios.sqrtRatioLowerX96, sqrtRatios.sqrtRatioUpperX96, params.amount0Desired, params.amount1Desired));

        
        console.log("amount0 actual", params.amount0Desired >= params.amount0Min);
        console.log("amount1 actual", params.amount1Desired >= params.amount1Min);
        require(params.amount0Desired >= params.amount0Min && params.amount1Desired >= params.amount1Min, "TOO MUCH SLIPPAGE");

        uint256 price = getRentalPrice(sqrtRatios, params, poolAddr);
        //require(price > 0, "POSITION TOO SMALL OR TOO FAR OUT OF RANGE");
        require(price <= params.priceMax, "RENTAL PRICE TOO HIGH");
        require(msg.value >= price, "INSUFFICIENT FUNDS");

        IERC20(params.token0).approve(address(rentPlatform), params.amount0Desired);
        IERC20(params.token1).approve(address(rentPlatform), params.amount0Desired);

        rentPoolFactory.drawLiquidity(params.token0, params.token1, params.amount0Desired, params.amount1Desired, address(rentPlatform));
       (, uint256 amount0, uint256 amount1) = rentPlatform.createNewRental(params, poolAddr, msg.sender);

        splitFees(pool0, pool1, amount0, amount1, price);
       
        //send back dust ETH
        if (msg.value > price) TransferHelper.safeTransferETH(msg.sender, msg.value - price);

    }

    function splitFees(IRentPool pool0, IRentPool pool1, uint256 amount0, uint256 amount1, uint256 price) internal {
         (uint token0Fee, uint token1Fee) = FeeMath.calculateFeeSplit(pool0, pool1, amount0, amount1, price* (1- premiumFee/10000));
        if (token0Fee > 0) TransferHelper.safeTransferETH(address(pool0), token0Fee);
        if (token1Fee > 0) TransferHelper.safeTransferETH(address(pool1), token1Fee);
        if (premiumFee > 0) TransferHelper.safeTransferETH(feeTo, price * premiumFee/10000);

    }
    
    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address token
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
        _addLiquidity(token);
        
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
        _addLiquidity(WETH);
        require(msg.value >= amountETH, "INSUFFICIENT FUNDS SENT");
        console.log("Getting WETH Pool");
        address pool = IRentPoolFactory(factory).getPool(WETH);
        console.log("depsoting ETH  into WETH contract");
        
        IWETH(WETH).deposit{ value : amountETH }();
        assert(IWETH(WETH).transfer(pool, amountETH));
        liquidity = IRentPool(pool).mint(to);
        require(liquidity >= amountMin, "INSUFFICIENT LIQUIDITY MINTED");
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }


    function withdrawPremiumFeesWithoutRemovingLiquidity(address token, uint feesMin, address to, uint deadline) ensure(deadline) override external returns (uint256 feesRecieved) {
        address pool = IRentPoolFactory(factory).getPool(token);
        feesRecieved = IRentPool(pool).withdrawPremiumFees(to);
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