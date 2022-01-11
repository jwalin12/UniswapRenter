pragma solidity =0.7.6;
pragma abicoder v2;

import "./interfaces/IRentPoolFactory.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import "./interfaces/IRentPlatform.sol";
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




    // function test(int24 tickUpper, int24 tickLower, uint256 durationInSeconds, address poolAddr, uint256 amountToken0) public view returns (PriceInfo memory) {
    //     PriceInfo memory price;
    //     price.uniswapPool = IUniswapV3Pool(poolAddr);
    //     (int24 meanTick, ) = OracleLibrary.consult(poolAddr, 60);
    //     price.meanTick = meanTick;
    //     price.token0Decimals = 10**IRentERC20(price.uniswapPool.token0()).decimals();
    //     price.token1Decimals = 10**IRentERC20(price.uniswapPool.token1()).decimals();
    //     //getQuoteAtTick returns token1/token0 (price of token0 in terms of token1)
    //     price.tokenAPrice = OracleLibrary.getQuoteAtTick(meanTick, uint128(price.token0Decimals), price.uniswapPool.token0(), price.uniswapPool.token1()); 
    //     price.tokenAPrice = FullMath.mulDiv(PRECISE_UNIT, price.tokenAPrice, price.token1Decimals);
    //     price.ratioLower = OracleLibrary.getQuoteAtTick(tickLower, uint128(PRECISE_UNIT), price.uniswapPool.token0(), price.uniswapPool.token1()); 
    //     price.ratioUpper = OracleLibrary.getQuoteAtTick(tickUpper, uint128(PRECISE_UNIT), price.uniswapPool.token0(), price.uniswapPool.token1());
    //     price.ratioMid = (price.ratioLower >> 1) + (price.ratioUpper >> 1) + (price.ratioLower & price.ratioUpper & 1);
    //     price.vol = optionGreekCache.getVol(poolAddr);
    //     price.rate = optionGreekCache.getRiskFreeRate();
    //     //option price is denominated in token1 and is scaled by amount of token0
    //     //since its denominated in token1, need to divide by token1 decimals to get actual number
    //     IBlackScholes.PricesDeltaStdVega memory optionPrices;
    //     if (price.tokenAPrice < price.ratioMid) {
    //         optionPrices = 
    //             blackScholes.pricesDeltaStdVega(
    //                 durationInSeconds,
    //                 optionGreekCache.getVol(poolAddr),
    //                 price.tokenAPrice,
    //                 price.ratioLower,
    //                 optionGreekCache.getRiskFreeRate()
    //             );
    //     } else {
    //         optionPrices = 
    //             blackScholes.pricesDeltaStdVega(
    //                 durationInSeconds,
    //                 optionGreekCache.getVol(poolAddr),
    //                 price.tokenAPrice,
    //                 price.ratioUpper,
    //                 optionGreekCache.getRiskFreeRate()
    //             );
    //     }
    //     price.call = FullMath.mulDiv(optionPrices.callPrice, amountToken0, price.token0Decimals);
    //     price.put = FullMath.mulDiv(optionPrices.putPrice, amountToken0, price.token0Decimals);
    //     return price;
    // }
    
    /**
   * @dev Returns the price (denominated in token1) of a rental LP with the given params. Mul by priceUSD(token1) to get rental price in USD.
   * @param tickUpper Upper tick of the range (where ratio is token1/token0)
   * @param tickLower Lower tick of range
   * @param durationInSeconds Duration of the rental in seconds
   * @param poolAddr Address of the Uniswap V3 token0-token1 pool
   * @param amountToken0 Amount of token0 (as a token0.decimals precision decimal) that should be contained within the rental position
   */
    function getRentalPrice(int24 tickUpper, int24 tickLower, uint256 durationInSeconds, address poolAddr, uint256 amountToken0) public view returns (uint256) {
        //instantiate stuff
        PriceInfo memory price;
        //TODO: fix minTick stuff
        price.uniswapPool = IUniswapV3Pool(poolAddr);
        if (tickLower <= TickMath.MIN_TICK) {
            console.log(tickLower == 0);
            tickLower = 1;
        }
        if (tickUpper >= TickMath.MAX_TICK) {
            tickUpper = TickMath.MAX_TICK;
        }

        //get price from oracle and get each token's decimals
        (int24 meanTick, ) = OracleLibrary.consult(poolAddr, 60);
        price.meanTick = meanTick;
        price.token0Decimals = 10**IRentERC20(price.uniswapPool.token0()).decimals();
        price.token1Decimals = 10**IRentERC20(price.uniswapPool.token1()).decimals();
        
        //calculate price of token1/token0 = price of token 0 in terms of token1
        //calculate price of upper and lower ticks and their mean
        price.tokenAPrice = OracleLibrary.getQuoteAtTick(meanTick, uint128(price.token0Decimals), price.uniswapPool.token0(), price.uniswapPool.token1()); 
        price.tokenAPrice = FullMath.mulDiv(PRECISE_UNIT, price.tokenAPrice, price.token1Decimals);
        console.log(price.tokenAPrice);
        price.ratioLower = OracleLibrary.getQuoteAtTick(tickLower, uint128(PRECISE_UNIT), price.uniswapPool.token0(), price.uniswapPool.token1()); 
        console.log(price.ratioLower);
        price.ratioUpper = OracleLibrary.getQuoteAtTick(tickUpper, uint128(PRECISE_UNIT), price.uniswapPool.token0(), price.uniswapPool.token1());
        console.log(price.ratioUpper);
        price.ratioMid = (price.ratioLower >> 1) + (price.ratioUpper >> 1) + (price.ratioLower & price.ratioUpper & 1);
        
        //option price is denominated in token1 and is scaled by amount of token0
        //since its denominated in token1, need to divide by token1 decimals to get actual number
        //and need to multiply by price of token1 in USD to get rental price in USD
        //since price is per unit (of token0), need to scale by amount of token0 to get total price
        //depending on whether ratio of token1/token0 is above mid or below mid, price as a call or a put
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
            return FullMath.mulDiv(optionPrices.callPrice, amountToken0, price.token0Decimals);
        } else {
            optionPrices = 
                blackScholes.pricesDeltaStdVega(
                    durationInSeconds,
                    optionGreekCache.getVol(poolAddr),
                    price.tokenAPrice,
                    price.ratioUpper,
                    optionGreekCache.getRiskFreeRate()
                );
            return FullMath.mulDiv(optionPrices.putPrice, amountToken0, price.token0Decimals);
        }
    }

    function buyRental(IRentPlatform.BuyRentalParams memory params) external payable {
        
        //check if enough liquidity is in the pool
        IRentPool pool0 = IRentPool(IRentPoolFactory(factory).getPool(params.token0));
        IRentPool pool1 = IRentPool(IRentPoolFactory(factory).getPool(params.token1));

        //check if price is right (call get price) and compare to slippage tolerance
        //create rental on existing rent platform
        console.log("getting pool...");
        address poolAddr = uniswapV3Factory.getPool(params.token0, params.token1, params.fee);
        require(poolAddr != address(0), "UNISWAP POOL DOES NOT EXIST");
        console.log("getting price...");
        console.log(params.amount0Desired);
        uint256 price = getRentalPrice(params.tickUpper, params.tickLower, params.duration, poolAddr, params.amount0Desired);
        require(price > 0, "POSITION TOO SMALL");
        require(price <= params.priceMax, "RENTAL PRICE TOO HIGH");
        require(msg.value >= price, "INSUFFICIENT FUNDS");

        //safe transfer amountDesired
        //TransferHelper.safeTransferFrom(params.token0, msg.sender ,address(this), params.amount0Desired);
        //TransferHelper.safeTransferFrom(params.token1, msg.sender ,address(this), params.amount1Desired);
        IERC20(params.token0).transferFrom(msg.sender, address(rentPlatform), params.amount0Desired);
        IERC20(params.token1).transferFrom(msg.sender, address(rentPlatform), params.amount1Desired);

       (uint256 tokenId, uint256 amount0, uint256 amount1) = rentPlatform.createNewRental(params, poolAddr, msg.sender);
        require(tokenId != 0, "FAILED TO CREATE RENTAL");
        console.log("CREATED RENTAL",tokenId);


        (uint token0Fee, uint token1Fee) = FeeMath.calculateFeeSplit(pool0, pool1, amount0, amount1, price* (1- premiumFee/10000));
        console.log("TOKEN0Fee", token0Fee);
        if (token0Fee > 0) TransferHelper.safeTransferETH(address(pool0), token0Fee);
        if (token1Fee > 0) TransferHelper.safeTransferETH(address(pool1), token1Fee);
        if (premiumFee > 0) TransferHelper.safeTransferETH(feeTo, price * premiumFee/10000);
        console.log("fee split");
        //send back dust ETH
        if (msg.value > price) TransferHelper.safeTransferETH(msg.sender, msg.value - price);


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