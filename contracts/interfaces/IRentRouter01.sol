pragma solidity >=0.5.0;
pragma abicoder v2;

import "../abstract/IRentPlatform.sol";


interface IRentRouter01 {

    function setFeeTo(address to) external;
    function setFeeToSetter(address to) external;
    function setFee(uint256 newFee) external;



    function addLiquidity(
        address token,
        uint amount,
        uint amountMin,
        address to,
        uint deadline
    ) external returns (uint liquidity);

    function addLiquidityETH(
        uint amountETH,
        uint amountMin,
        address to,
        uint deadline
    ) external payable returns (uint liquidity);

    function removeLiquidityWithPermit(
        address token,
        uint amount,
        uint amountMin,
        uint feesMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountTokensRecieved, uint feesRecieved);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountTokensRecieved, uint feesRecieved);

    function quoteRental(IRentPlatform.BuyRentalParams memory params) external returns (uint256 rentalPrice);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        uint amount,
        uint amountMin,
        uint amountFeesMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function withdrawPremiumFeesWithoutRemovingLiquidity(address token, uint feesMin, address to, uint deadline) external returns (uint256 feesRecieved);




}