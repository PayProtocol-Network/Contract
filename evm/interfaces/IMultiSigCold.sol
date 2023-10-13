//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "./IMerchantData.sol";

interface IMultiSigCold {
    function createMerchant(
        address _merKey, merchantData memory data,  address[] memory _hotManager,address[] memory _coldManager, address _utcPayKey
    ) external;
}
