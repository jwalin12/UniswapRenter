pragma solidity =0.7.6;

import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './libraries/SafeMath.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './interfaces/IRentPool.sol';
import './RentERC20.sol';
import './interfaces/IRentPoolFactory.sol';

contract RentPool is IRentPool, RentERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token;

    uint112 private reserve;           // uses single storage slot, accessible via getReserves
    uint112 private feesAccrued; 
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves


    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve, uint112 feesAccrued, uint32 _blockTimestampLast) {
        _reserve = reserve;
        feesAccrued = feesAccrued;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint amount);
    event Burn(address indexed sender, uint amount,  address indexed to);
    event WithdrawFees(address indexed to, uint amount);
    event Sync(uint112 reserve);

    constructor() public {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token) override external {
        require(msg.sender == factory, 'FORBIDDEN'); // sufficient check
        token = _token;

    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint112 balance, uint112 _reserve) private {
        require(balance <= uint112(-1), 'OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserve = uint112(balance);
        feesAccrued = uint112(address(this).balance);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve);
    }

    function _mintFee() private returns (bool feeOn) {
        address feeTo = IRentPoolFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        return feeOn;
 
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external override lock returns (uint liquidity) {
        (uint112 _reserve, ,) = getReserves(); // gas savings
        uint balance = IERC20(token).balanceOf(address(this));
        uint amount = balance.sub(reserve);
        if (totalSupply == 0) {
            liquidity = amount.sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = amount;
        }
        require(liquidity > 0, 'INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);
        _update(uint112(balance), _reserve);
        emit Mint(msg.sender, amount);
    }

    // this low-level function should be called from a contract which performs important safety checks
    //before calling this, router must transfer tokens to burn address
    function burn(address payable to) external override lock returns (uint amount) {
        (uint112 _reserve, uint112 feesAccrued,) = getReserves(); // gas savings
        address _token = token;                                // gas savings
        uint balance = IERC20(_token).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee();
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        uint256 amountOfTokens = liquidity.mul(balance) / _totalSupply; // using balances ensures pro-rata distribution
        uint256 amountOfFees = liquidity.mul(feesAccrued)/ _totalSupply;
        require(amountOfTokens > 0, 'INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(token, to, amountOfTokens);
        to.transfer(amountOfFees);

        balance = IERC20(_token).balanceOf(address(this));
        _update(uint112(balance), _reserve);
        emit Burn(msg.sender, amountOfTokens, to);
    }


    // this low-level function should be called from a contract which performs important safety checks
    function withdrawFees (address payable to) external {
        (, uint112 feesAccrued,) = getReserves(); // gas savings
        address _token = token;
        uint liquidity = balanceOf[address(to)];
        uint256 amountOfFees = liquidity.mul(feesAccrued)/ totalSupply;
        require(amountOfFees > 0, 'NO_FEES_ACCRUED');
        to.transfer(amountOfFees);
        uint256 balance = IERC20(_token).balanceOf(address(this));
        _update(uint112(balance), reserve);
        emit WithdrawFees(to, amountOfFees);
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