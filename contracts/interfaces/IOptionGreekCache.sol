pragma solidity >= 0.7.6;

interface IOptionGreekCache {

    function getRiskFreeRate() external view returns (int256);
    function setRiskFreeRate(int256 newRate) external;
    function getVol(address poolAddr) external view returns (uint256);
    function setPoolAddressToVol(address poolAddr, uint256 newVol) external;
    function addAuthorizedUser(address newUser) external;
    function removeAuthorizedUser(address userToRemove) external;
}