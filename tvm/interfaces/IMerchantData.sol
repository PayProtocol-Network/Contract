//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

struct merchantData {
    address payable _hotPool;
    address payable _coldPool;
    uint256 _hotCoinMaxRatio;
    uint256 _feeRateToUtcPay;
    uint256 _balancedTime;
    uint256 _minVoteRatio;
    uint256 _voteDuration;
    address _primAgentAddr;
    address _secAgentAddr;
    uint256 _primAgentProfitPerc;
    uint256 _secAgentProfitPerc;
}

