//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

interface IMultiSigHot {

    function createHotManager(
        address _merKey, address[] memory _hotManager
    ) external;

    function addManager(address _managerConfigAddr, address _target ) external;
    function rmManager(address _managerConfigAddr, address _target ) external;
}
