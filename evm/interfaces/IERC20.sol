//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _form, address _to, uint256 _value) external returns (bool);
    function approve(address _spender, uint256 _value) external  returns (bool success);
}
