//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

interface IHot {
    function transferErc20(address _erc20s, address[] memory _to, uint256[] memory _amounts, uint256 _orders) external;
    function transferEth(address[] memory _to, uint256[] memory _amounts, uint256 _orders) external;
}
