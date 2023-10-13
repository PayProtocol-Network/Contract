//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

interface IMC {
    function parameters()external view returns (address,bytes memory);
}