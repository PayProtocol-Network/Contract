//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./IMerchantData.sol";

interface IMerchantConfigExt {

    struct MerchantAgentConfigData {
        address primAgentAddr;
        address secAgentAddr;
        uint256 primAgentProfitPerc;
        uint256 secAgentProfitPerc;
        address feeUtcPayAddr;
        uint256 feeRateToUtcPay;
    }

    function getErc20sAmdMerPool(address _merKey)external view returns (address[] memory,address payable,address payable);

    function getOneErc20AmdMerPool(uint index, address _merKey)external view returns (address,address payable,address payable);

    function getMerColdPool(address _merKey) external view returns (address payable);

    function getMerHotPool(address _merKey) external view returns (address payable);

    function getMerBalancedTime(address _merKey) external view returns (uint256) ;

    function getMerMaxRatio(address _merKey) external view returns (uint256) ;

    function getMerMinVoteRatio(address _merKey) external view returns (uint256);

    function getMerVoteDuration(address _merKey) external view returns (uint256);

    function getMerHotBal(address _merKey, address erc20) external view returns (uint256);

    function getMerColdBal(address _merKey, address erc20) external view returns (uint256);

    function getMerchantData(address _merKey) external view returns (
        address balanceManager,
        address payable hotPool,
        address payable coldPool,
        uint256 hotCoinMaxRatio,
        uint256 balancedTime,
        uint256 minVoteRatio,
        uint256 voteDuration
    );

    function getMerAgentConfigData(address _merKey) external view returns (MerchantAgentConfigData memory);

    function withdrawHotBalance(address _merKey, address _erc20Addr, uint256 _aomunt) external;

    function updateContractBalance(address _merKey, address _erc20Addr, address tokenPool) external;

    function setMerchant(address _merKey,merchantData memory data) external;

    function updateHotCoinMaxRatio(address _merKey, uint256 _value) external;

    function updateBalancedTime(address _merKey, uint256 _value) external;

    function updateMinVoteRatio(address _merKey, uint256 _value) external;

    function updateVoteDuration(address _merKey, uint256 _value) external;

    function updateFee(address _merKey, uint256 _value, uint256 _value1, uint256 _value2) external;

    function updateFeeUtcPayAddr(address _target) external;

    function updPrimAgentAddr(address _merKey, address _target) external;

    function updSecAgentAddr(address _merKey, address _target) external;

    function getHotBalanceFunds(uint256 hotErc20BalanceOf, uint256 coldErc20BalanceOf,uint256 hotCoinMaxRatio)external pure returns(uint256);

    function updateMerchantHotBalance(address _merKey, address _erc20Addr, uint256 _value) external;
    
    function addErc20s(address _erc20) external;
    
    function removeErc20s(address _erc20) external;

    function transferOwnership(address newOwner) external ;
}
