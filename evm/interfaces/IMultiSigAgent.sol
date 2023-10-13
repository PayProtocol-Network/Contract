//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

interface IMultiSigAgent {
    function createAgent(address _agentKey, address[] memory _manager) external;
}
