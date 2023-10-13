//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

interface IMultiSigAgent {
    function createAgent(address _agentKey, address[] memory _manager) external;
}
