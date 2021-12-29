pragma solidity =0.7.6;
pragma abicoder v2;

import "./interfaces/IRentPoolFactory.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import "./libraries/TickMath.sol";
import "./interfaces/IRentPlatform.sol";
import './interfaces/IRentRouter01.sol';
import './interfaces/IBlackScholes.sol';
import './interfaces/IRentPool.sol';
import './interfaces/IRentERC20.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './interfaces/IWETH.sol';
import './OptionGreekCache.sol';
import './BlackScholes.sol';
import "hardhat/console.sol";
import "./synthetix/SignedSafeDecimalMath.sol";
import "./synthetix/SafeDecimalMath.sol";

contract CaravanRentRouter01 is IRentRouter01 {
    using SafeMath for uint;
    using SafeDecimalMath for uint;
    using SignedSafeMath for int;
    using SignedSafeDecimalMath for int;

    /// @dev Internally this library uses 27 decimals of precision
    uint private constant PRECISE_UNIT = 1e27;

    address public immutable factory;
    address public immutable WETH;

    OptionGreekCache private immutable optionGreekCache;
    BlackScholes private immutable blackScholes;
    IUniswapV3Factory private immutable uniswapV3Factory;
    uint32[] private observationRange;

    struct PriceInfo {
        IUniswapV3Pool uniswapPool;
        uint tokenAPrice;
        uint ratioLower;
        uint ratioUpper;
        uint ratioMid;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'RentRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH, address optionGreekCacheAddress, address blackScholesAddress, address uniswapV3FactoryAddress) public {
        factory = _factory;
        WETH = _WETH;
        observationRange.push(0);
        observationRange.push(1);
        optionGreekCache = OptionGreekCache(optionGreekCacheAddress);
        blackScholes = BlackScholes(blackScholesAddress);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3FactoryAddress);
    }

    receive() external payable {
    }
    
    /**
   * @dev Returns the price (in token0?) of a rental LP with the given params
   * @param tickUpper Upper tick of the range (where ratio is token1/token0)
   * @param tickLower Lower tick of range
   * @param durationInSeconds Duration of the rental in seconds
   * @param poolAddr Address of the Uniswap V3 token0-token1 pool
   * @param amountToken1Decimal Amount of token1 as a 27 precision decimal that should be contained within the rental position (with token0 liquidity provided as given by current ratio)
   */
    function getRentalPrice(int24 tickUpper, int24 tickLower, uint256 durationInSeconds, address poolAddr, uint256 amountToken1Decimal) public view returns (uint256) {
        PriceInfo memory price;
        price.uniswapPool =  IUniswapV3Pool(poolAddr);
        (int56[] memory ticks,) = price.uniswapPool.observe(observationRange);
        //ticks[1] and ticks[0] are int56
        price.tokenAPrice = TickMath.getSqrtRatioAtTick(ticks[1] - ticks[0]); //sqrt of the ratio of the two assets (token1/token0)
        price.ratioLower = TickMath.getSqrtRatioAtTick(tickLower); //sqrt of the ratio of the two assets (token1/token0)
        price.ratioUpper = TickMath.getSqrtRatioAtTick(tickUpper);
        price.ratioLower = price.ratioLower.mul(price.ratioLower);
        price.ratioUpper = price.ratioUpper.mul(price.ratioUpper);
        price.ratioMid = price.ratioLower + (price.ratioLower + price.ratioUpper) / 2;
        //the mid price is wrong. It must be calculated using the squared ratios, not the sqrts.

        if (price.tokenAPrice > price.ratioMid) {
            IBlackScholes.PricesDeltaStdVega memory optionPrices =
                blackScholes.pricesDeltaStdVega(
                durationInSeconds,
                optionGreekCache.getVol(poolAddr),
                price.tokenAPrice,
                price.ratioUpper,
                optionGreekCache.getRiskFreeRate()
            ); // [<call price> , <put price> , <call delta> , <put delta> ] everything is in decimals            
            return optionPrices.putPrice.multiplyDecimalRoundPrecise(amountToken1Decimal.divideDecimalRoundPrecise(PRECISE_UNIT.mul(100)));
        } else {
            IBlackScholes.PricesDeltaStdVega memory optionPrices =
                blackScholes.pricesDeltaStdVega(
                durationInSeconds,
                optionGreekCache.getVol(poolAddr),
                price.tokenAPrice,
                price.ratioLower,
                optionGreekCache.getRiskFreeRate()
            ); // [<call price> , <put price> , <call delta> , <put delta> ] everything is in decimals            
            return optionPrices.callPrice.multiplyDecimalRoundPrecise(amountToken1Decimal.divideDecimalRoundPrecise(PRECISE_UNIT.mul(100)));
        }
        //instantiate uniswap v3 pool
        //instantiate BlackScholes
        //call observe to pool twice to get 2 tick readings
        //do math to get TWAP based on tick readings
        //if TWAP > mid of position range, call BlackScholes put with strike price as upper tick 
        //else call BlackScholes call with strike price as lower tick
        //return whatever BlackScholes did
    }

    function buyRentalListing(IRentPlatform.BuyRentalParams memory params) external payable {
        
        //check if enough liquidity is in the pool
        IRentPool pool0 = IRentPool(IRentPoolFactory(factory).getPool(params.token0));
        IRentPool pool1 = IRentPool(IRentPoolFactory(factory).getPool(params.token1));
        //check if price is right (call get price) and compare to slippage tolerance
        //create rental on existing rent platform
        address poolAddr = uniswapV3Factory.getPool(params.token0, params.token1, params.fee);
        require(poolAddr != address(0), "UNISWAP POOL DOES NOT EXIST");
        uint256 price = getRentalPrice(params.tickUpper, params.tickLower, params.duration, poolAddr, params.amount1Desired);
        require(price <= params.priceMax, "RENTAL PRICE TOO HIGH");
        require(msg.value >= price, "INSUFFICIENT FUNDS");
        if (msg.value > price) TransferHelper.safeTransferETH(msg.sender, msg.value - price);

        //send back dust ETH 
        //who is the owner of these rentals? managerial contract that we can collect fees from? or rent platform contract which could do the same.
        //rent platform handles everything with rentals and owns all pool rentals
        //when interacting with pool, use functions in this router
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
        console.log("Asserting");
        assert(IWETH(WETH).transfer(pool, amountETH));
        console.log("Minting");
        liquidity = IRentPool(pool).mint(to);
        console.log(amountMin);
        console.log(liquidity);
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