pragma solidity =0.7.6;

import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRentPool.sol";
import "./RentERC20.sol";
import "./interfaces/IRentPoolFactory.sol";
import "./libraries/TickMath.sol";
import "hardhat/console.sol";


contract RentPool is IRentPool, RentERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token;

    uint112 private reserve;           // uses single storage slot, accessible via getReserves
    uint256 private feesAccrued; 
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves


    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "UniswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    receive() external payable {
        feesAccrued += msg.value;
    }


    function _getReserves() private view returns (uint112 _reserve, uint256 _feesAccrued, uint32 _blockTimestampLast) {
        _reserve = reserve;
        _feesAccrued = feesAccrued;
        _blockTimestampLast = blockTimestampLast;

    }

    function getReserves() external override view returns (uint112 _reserve, uint256 _feesAccrued, uint32 _blockTimestampLast) {
        return _getReserves();
    }


    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }

    event Mint(address indexed sender, uint amount);
    event Burn(address indexed sender, uint amount,  address indexed to);
    event WithdrawPremiumFees(address indexed to, uint amount);
    event Sync(uint112 reserve);

    constructor() public {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token) override external {
        require(msg.sender == factory, "FORBIDDEN"); // sufficient check
        token = _token;

    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint112 balance, uint112 _reserve) private {
        require(balance <= uint112(-1), "OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserve = uint112(balance);
        feesAccrued = uint112(address(this).balance);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve);
    }

    function _mintFee(uint256 liquidity) private returns (bool feeOn) {
        address feeTo = IRentPoolFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        if (feeOn) {
            _mint(feeTo, liquidity * (IRentPoolFactory(factory).getFee()/10000));
        }
        return feeOn;
 
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external override lock returns (uint liquidity) {
        (uint112 _reserve, ,) = _getReserves(); // gas savings
        uint balance = IERC20(token).balanceOf(address(this));
        uint amount = balance.sub(reserve);
        if (totalSupply == 0) {
            liquidity = amount.sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = amount;
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        if (_mintFee(liquidity)) {
            _mint(to, liquidity* (1 - (IRentPoolFactory(factory).getFee()/10000)));
        } else {
            _mint(to, liquidity);
        }
        _update(uint112(balance), _reserve);
        emit Mint(msg.sender, amount);
    }

    // this low-level function should be called from a contract which performs important safety checks
    //before calling this, router must transfer tokens to burn address
    function burn(address to) external override lock returns (uint amountOfTokens, uint256 feesAccrued) {
        (uint112 _reserve, uint256 feesAccrued,) = _getReserves(); // gas savings
        address _token = token;                                // gas savings
        uint balance = IERC20(_token).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        uint256 amountOfTokens = liquidity.mul(balance) / _totalSupply; // using balances ensures pro-rata distribution
        uint256 amountOfFees = liquidity.mul(feesAccrued)/ _totalSupply;
        require(amountOfTokens > 0, "INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(token, to, amountOfTokens);
        payable(to).transfer(amountOfFees);

        balance = IERC20(_token).balanceOf(address(this));
        _update(uint112(balance), _reserve);
        emit Burn(msg.sender, amountOfTokens, to);
    }


    // this low-level function should be called from a contract which performs important safety checks
    function withdrawPremiumFees (address to) external override returns (uint256 amountOfFees) {
        (, uint256 feesAccrued,) = _getReserves(); // gas savings
        address _token = token;
        uint liquidity = balanceOf[address(to)];
        amountOfFees = liquidity.mul(feesAccrued)/ totalSupply;
        require(amountOfFees > 0, "NO_FEES_ACCRUED");
        payable(to).transfer(amountOfFees);
        uint256 balance = IERC20(_token).balanceOf(address(this));
        _update(uint112(balance), reserve);
        emit WithdrawPremiumFees(to, amountOfFees);
    }


    // force balances to match reserves
    function skim(address to) external override lock {
        address token = token; // gas savings
        _safeTransfer(token, to, IERC20(token).balanceOf(address(this)).sub(reserve));
    }

    // force reserves to match balances
    function sync() external override lock {
        _update(uint112(IERC20(token).balanceOf(address(this))), reserve);
    }
}