pragma solidity =0.7.6;

import './interfaces/IRentPoolFactory.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/IRentRouter01.sol';
import './interfaces/IRentPool.sol';
import './interfaces/IRentERC20.sol';
import './libraries/SafeMath.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './interfaces/IWETH.sol';

contract UniswapV2Router02 is IRentRouter01 {
    using SafeMath for uint;

    address public immutable factory;
    address public immutable WETH;

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