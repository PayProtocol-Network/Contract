//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMerchantConfigExt.sol";
import "./interfaces/IERC20.sol";

/// @title Merchant configuration template contract
/// @notice Record the configuration information of all merchants

contract MerchantConfigExt is Ownable{
    /// @dev configuration supported ERC20
    address[] public erc20s;
    /// @dev utcpay handling fee address
    address payable public feeUtcPayAddr;
    
    struct Merchant {
        /// Merchant key, used to identify the merchant
        address balanceManager;
        /// Hot contract storage pool address
        address payable hotPool;
        /// Cold contract storage pool address
        address payable coldPool;
        /// Set the storage balance ratio of each merchant's hot contract
        uint256 hotCoinMaxRatio;
        /// Fee payment ratio for each merchant
        uint256 feeRateToUtcPay;
        /// Each merchant balance funds limit time
        uint256 balancedTime;
        /// The minimum voting ratio for multiple signatures for each merchant is at least 50 and the maximum is 100
        uint256 minVoteRatio;
        /// Voting time limit for each merchant
        uint256 voteDuration;
        /// First-level agency commission transfer contract address
        address primAgentAddr;
        /// Secondary agency commission transfer contract address
        address secAgentAddr;
        /// First-level agent commission ratio
        uint256 primAgentProfitPerc;
        /// Secondary agent commission ratio
        uint256 secAgentProfitPerc;
    }

    mapping(address => Merchant) public merchants;//Business configuration

    constructor(address payable _feeUtcPayAddr) Ownable() {
        feeUtcPayAddr = _feeUtcPayAddr;
    }

    
    /// @dev Configure merchant initialization data
    /// @param _merKey Merchant ID
    /// @param data Merchant configuration data
    function setMerchant(
        address _merKey,
        merchantData memory data
    ) external onlyOwner {
        require(merchants[_merKey].balanceManager == address(0) && _merKey!=address(0), "Merchant already exists");
        Merchant storage merchant = merchants[_merKey];
        merchant.balanceManager = _merKey;
        merchant.hotPool = data._hotPool;
        merchant.coldPool = data._coldPool;
        merchant.hotCoinMaxRatio = data._hotCoinMaxRatio;
        merchant.feeRateToUtcPay = data._feeRateToUtcPay;
        merchant.balancedTime = data._balancedTime;
        merchant.minVoteRatio = data._minVoteRatio;
        merchant.voteDuration = data._voteDuration;
        merchant.primAgentAddr = data._primAgentAddr;
        merchant.secAgentAddr = data._secAgentAddr;
        merchant.primAgentProfitPerc = data._primAgentProfitPerc;
        merchant.secAgentProfitPerc = data._secAgentProfitPerc;
    }
    
    /// @dev Get merchant configuration
    /// @param _merKey Merchant ID
    function getMerchantData(address _merKey) external view returns (
        address balanceManager,
        address payable hotPool,
        address payable coldPool,
        uint256 hotCoinMaxRatio,
        uint256 balancedTime,
        uint256 minVoteRatio,
        uint256 voteDuration
    ) {
        Merchant storage merchant = merchants[_merKey];
        balanceManager  = merchant.balanceManager;
        hotPool         = merchant.hotPool;
        coldPool        = merchant.coldPool;
        hotCoinMaxRatio = merchant.hotCoinMaxRatio;
        balancedTime    = merchant.balancedTime;
        minVoteRatio    = merchant.minVoteRatio;
        voteDuration    = merchant.voteDuration;
    }


    /// @dev Get merchant commission configuration
    /// @param _merKey Merchant ID
    function getMerAgentConfigData(address _merKey) external view returns (
        IMerchantConfigExt.MerchantAgentConfigData memory
    ){
        Merchant storage merchant = merchants[_merKey];
        return IMerchantConfigExt.MerchantAgentConfigData(
            merchant.primAgentAddr,
            merchant.secAgentAddr,
            merchant.primAgentProfitPerc,
            merchant.secAgentProfitPerc,
            feeUtcPayAddr,
            merchant.feeRateToUtcPay
        );
    }

    /// @dev Get the merchant cold contract storage pool address
    /// @param _merKey Merchant ID
    function getMerColdPool(address _merKey) external view returns (address payable) {
        return merchants[_merKey].coldPool;
    }

    /// @dev Get the merchant hot contract storage pool address
    /// @param _merKey Merchant ID
    function getMerHotPool(address _merKey) external view returns (address payable) {
        return merchants[_merKey].hotPool;
    }

    /// @dev Get merchant balance fund limit time
    /// @param _merKey Merchant ID
    function getMerBalancedTime(address _merKey) external view returns (uint256) {
        return merchants[_merKey].balancedTime;
    }

    /// @dev Get the merchant's storage balance ratio
    /// @param _merKey Merchant ID
    function getMerMaxRatio(address _merKey) external view returns (uint256) {
        return merchants[_merKey].hotCoinMaxRatio;
    }

    /// @dev Get the proportion of merchants who voted through
    /// @param _merKey Merchant ID
    function getMerMinVoteRatio(address _merKey) external view returns (uint256) {
        return merchants[_merKey].minVoteRatio;
    }

    /// @dev Get merchant voting limit time
    /// @param _merKey Merchant ID
    function getMerVoteDuration(address _merKey) external view returns (uint256) {
        return merchants[_merKey].voteDuration;
    }

    /// @dev Get the balance of the merchant's erc20 hot contract storage pool
    /// @param _merKey Merchant ID
    /// @param erc20 token address
    function getMerHotBal(address _merKey, address erc20) external view returns (uint256){
        require(merchants[_merKey].hotPool != address(0), "hot");
        uint256 bal = 0;
        if(erc20 == address(0)) {
            bal = merchants[_merKey].hotPool.balance;
        } else {
            bal = IERC20(erc20).balanceOf(merchants[_merKey].hotPool);
        }
        return bal;
    }

    /// @dev Get the balance of the merchant's erc20 cold contract storage pool
    /// @param _merKey Merchant ID
    /// @param erc20 token address
    function getMerColdBal(address _merKey, address erc20) external view returns (uint256){
        require(merchants[_merKey].coldPool != address(0), "cold");
        uint256 bal = 0;
        if(erc20 == address(0)) {
            bal = merchants[_merKey].coldPool.balance;
        } else {
            bal = IERC20(erc20).balanceOf(merchants[_merKey].coldPool);
        }
        return bal;
    }

    /// @dev Add erc20 token address, add supported currency for the contract
    /// @param _erc20 token address
    function addErc20s(address _erc20) external onlyOwner {
        erc20s.push(_erc20);
    }

    /// @dev delete erc20 currency
    /// @param _erc20 currency address
    function removeErc20s(address _erc20) external onlyOwner {
        for(uint i;i<erc20s.length;++i){
            if(_erc20==erc20s[i]){
                erc20s[i]=erc20s[erc20s.length-1];
                delete erc20s[erc20s.length-1];
                erc20s.pop();
                break;
            }
        }
    }


    /// @dev Get all erc20 token addresses, and merchant hot and cold contract addresses
    /// @param _merKey Merchant ID    
    function getErc20sAmdMerPool(address _merKey)external view returns (address[] memory,address payable,address payable){
        return (erc20s,merchants[_merKey].coldPool,merchants[_merKey].hotPool);
    }

    /// @dev Get an erc20 token address, and merchant hot and cold contract addresses
    /// @param index array identifier
    /// @param _merKey Merchant ID   
    function getOneErc20AmdMerPool(uint index, address _merKey)external view returns (address,address payable,address payable){
        return (erc20s[index],merchants[_merKey].coldPool,merchants[_merKey].hotPool);
    }

    /// @dev Calculate hot and cold contract balance distribution
    /// @param hotErc20BalanceOf hot contract balance
    /// @param coldErc20BalanceOf cold contract balance
    /// @param hotCoinMaxRatio distribution ratio
    function getHotBalanceFunds(uint256 hotErc20BalanceOf, uint256 coldErc20BalanceOf,uint256 hotCoinMaxRatio)external pure returns(uint256) {
        /// Hot contracts account for the total balance
        uint256 hotErc20Total = (hotErc20BalanceOf+coldErc20BalanceOf)*hotCoinMaxRatio/1e2;
        /// The amount transferred to the hot contract (and the cold contract to reduce funds)
        uint256 hotTransferErc20BalanceOf = hotErc20Total <= hotErc20BalanceOf?0:hotErc20Total - hotErc20BalanceOf;
        return hotTransferErc20BalanceOf;
    }

    /// @dev Modify the merchant's storage balance ratio
    /// @param _merKey Merchant ID
    /// @param _value target value
    function updateHotCoinMaxRatio(address _merKey, uint256 _value) external onlyOwner checkMerKey(_merKey) {
        merchants[_merKey].hotCoinMaxRatio = _value;
    }

    /// @dev Modify merchant balance fund limit time
    /// @param _merKey Merchant ID
    /// @param _value target value
    function updateBalancedTime(address _merKey, uint256 _value) external onlyOwner checkMerKey(_merKey) {
        merchants[_merKey].balancedTime = _value;
    }

    /// @dev Modify the proportion of merchants voting
    /// @param _merKey Merchant ID
    /// @param _value target value
    function updateMinVoteRatio(address _merKey, uint256 _value) external onlyOwner checkMerKey(_merKey) {
        require(_value>=50 && _value<=100,"_value");
        merchants[_merKey].minVoteRatio = _value;
    }

    /// @dev Modify merchant voting limit time
    /// @param _merKey Merchant ID
    /// @param _value target value
    function updateVoteDuration(address _merKey, uint256 _value) external onlyOwner checkMerKey(_merKey) {
        merchants[_merKey].voteDuration = _value;
    }

    /// @dev modify merchant commission ratio
    /// @param _merKey Merchant ID
    /// @param _value target value
    /// @param _value1 target value
    /// @param _value2 target value
    function updateFee(address _merKey, uint256 _value, uint256 _value1, uint256 _value2) external onlyOwner checkMerKey(_merKey) {
        merchants[_merKey].feeRateToUtcPay = _value;
        merchants[_merKey].primAgentProfitPerc = _value1;
        merchants[_merKey].secAgentProfitPerc = _value2;
    }

    /// @dev Modify commission transfer address
    /// @param _target target address
    function updateFeeUtcPayAddr(address payable  _target) external onlyOwner {
        feeUtcPayAddr = _target;
    }

    /// @dev Modify the commission address of the first-level agent
    /// @param _merKey Merchant ID
    /// @param _target target address
    function updPrimAgentAddr(address _merKey, address _target) external onlyOwner checkMerKey(_merKey) {
        merchants[_merKey].primAgentAddr = _target;
    }

    /// @dev modify the commission address of the secondary agent
    /// @param _merKey Merchant ID
    /// @param _target target address
    function updSecAgentAddr(address _merKey, address _target) external onlyOwner checkMerKey(_merKey) {
        merchants[_merKey].secAgentAddr = _target;
    }

    /// @dev Check if the merchant ID exists
    /// @param _merKey Merchant ID
    modifier checkMerKey(address _merKey) {
        require(merchants[_merKey].balanceManager == _merKey && merchants[_merKey].balanceManager!=address(0), "Only configs contracts can call this function");
        _;
    }

}