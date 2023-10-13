//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./interfaces/IMerchantData.sol";
import "./interfaces/IMerchantConfigExt.sol";
import "./interfaces/ICold.sol";
import "./interfaces/IHot.sol";
import "./interfaces/MultiSig.sol";
import "./interfaces/IMultiSigHot.sol";

/// @title Cold contract multi-signature
/// @notice Multi-signature management merchant data
contract MultiSigCold{

    using MultiSig for MultiSig.managerConfig;
    using MultiSig for mapping(address => mapping (uint256 => MultiSig.Proposal));
    using MultiSig for mapping(address => MultiSig.Manager);

    address public configExtAddr; /// Merchant configuration template address
    address public hotMulAddr;/// Hot contract Multisig address (for modification)
    uint256 public constant VOTE_DURATION = 86400;
    uint256 public constant MIN_VOTE_RATIO = 60;
    uint256 public constant VALUE = 0;

    /// @dev Merchant Proposal List
    mapping(address => mapping (uint256 => MultiSig.Proposal)) public coldProposals;

    /// @dev Merchant multi-sign administrator information
    mapping(address => MultiSig.managerConfig) public coldManagerConfigs;
    /// @dev The current proposal has been voted on by the admin
    mapping(address => mapping(uint256 => mapping (address => bool))) public coldConfirmations;
     /// @dev is an administrator
    mapping(address => mapping(address => MultiSig.Manager)) public coldManagers;
    

    /// @dev utcpay 多签配置
    mapping(address => mapping (uint256 => MultiSig.Proposal)) public proposals;

    mapping(address =>  MultiSig.managerConfig) public managerConfigs;
    
    mapping(address =>  mapping(uint256 => mapping (address => bool))) public confirmations;
    /// @dev is an administrator
    mapping(address =>  mapping(address => MultiSig.Manager)) public Managers;


    /// @dev Merchant's last time to balance funds
    mapping(address => uint256) public merchantLastBalancedTime;

    event Voted(address indexed merchant, uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(address indexed merchant, uint256 indexed proposalId);
    event ProposalCreated(uint256 indexed _proposalId);
    event ColdVotesResult(bool indexed status);

    /// @param _configExtAddr merchant template contract address
    /// @param _utcpayManager The multi-signature administrator adds three unique data by default
    /// @param _utcPayKey utcpay identification
    constructor(address _configExtAddr, address[] memory _utcpayManager, address _utcPayKey) mangerLen(_utcpayManager.length){
        managerConfigs[_utcPayKey].createManager(_utcPayKey, _utcpayManager);
        /// Add utc administrator
        for (uint i = 0; i < _utcpayManager.length; i++) {
            Managers[_utcPayKey].addManager(_utcpayManager[i]);
        }
        configExtAddr = _configExtAddr;
    }

    /// @dev Initialize merchant creation with utc administrator
    /// @param _merKey Merchant ID
    /// @param data Merchant initialization data
    /// @param _hotManager Merchant hot contract multi-signature manager
    /// @param _coldManager Merchant cold contract multi-signature manager
    /// @param _utcPayKey utcpay identification
    function createMerchant(
        address _merKey, merchantData memory data,  address[] memory _hotManager,address[] memory _coldManager, address _utcPayKey
    ) external onlyUtcPayManager(_utcPayKey) mangerLen(_coldManager.length) {
        require(_utcPayKey != _merKey);
        IMerchantConfigExt(configExtAddr).setMerchant(_merKey, data);
        
        coldManagerConfigs[_merKey].createManager(_merKey, _coldManager);
        /// Initialize the multi-signature administrator for each merchant
        for (uint i = 0; i < _coldManager.length; i++) {
            coldManagers[_merKey].addManager(_coldManager[i]);
        }
        /// Create hot contract manager
        IMultiSigHot(hotMulAddr).createHotManager(_merKey, _hotManager);
    }
    
    /// @dev Modify hot contract multi-signature address
    /// @param _hotMulAddr hot contract multi-signature address
    /// @param _utcPayKey utcpay identification
    function setmulHotAddr(address _hotMulAddr,  address _utcPayKey) external onlyUtcPayManager(_utcPayKey){
        hotMulAddr = _hotMulAddr;
    }

    /// @dev modify the first-level proxy contract address
    /// @param _merKey Merchant ID
    /// @param _target target address
    /// The operation of the TODO method is controversial, whether to adjust
    function updPrimAgentAddr(address _merKey, address _target) internal {
        IMerchantConfigExt(configExtAddr).updPrimAgentAddr(_merKey, _target);
    }

    /// @dev modify the address of the secondary proxy contract
    /// @param _merKey Merchant ID
    /// @param _target target address
    /// The operation of the TODO method is controversial, whether to adjust
    function updSecAgentAddr(address _merKey, address _target) internal {
        IMerchantConfigExt(configExtAddr).updSecAgentAddr(_merKey, _target);
    }
    
    /// @dev cold contract administrator proposal
    /// @param _merKey Merchant ID
    /// @param _proposalType proposal type
    /// @param _target target address
    /// @param _value target value
    function createColdProposal(address _merKey, uint8 _proposalType, address _target, uint256 _value,  uint256 _proposalId)
        external
        onlyColdManager(_merKey)
    {
        require(coldProposals[_merKey][_proposalId].endTime == 0, "The current proposal id exists");
        /// Allowed proposal types
        onlyColdProposalType(_proposalType);

        require(_proposalType !=uint8(MultiSig.ProposalType.FeeRatio) ,"No proposal permission for current category");
        if(_proposalType == uint8(MultiSig.ProposalType.MinVoteRatio)){
            require(_value>= 50 && _value<=100,"Minimum voting rate must be greater than or equal to 50 and less than or equal to 100");
        }
        if(_proposalType == uint8(MultiSig.ProposalType.HotCoinMaxRatio)){
            require(_value<=100,"The maximum ratio cannot be greater than 100");
        }

        MultiSig.ProposalData memory args = MultiSig.ProposalData({
            key: _merKey,
            targetKey: address(0),
            endTime:0,
            proposalType: _proposalType,
            target: _target,
            value: _value,
            value1: 0,
            value2: 0,
            minVoteRatio: 0,
            voteCount: 1
        });

       _createProposal(args, _proposalId);
       
    }

    /// @dev utcpay admin proposal
    /// @param _merKey Merchant ID
    /// @param _proposalType proposal type
    /// @param _target target address
    /// @param _value target value
    /// @param _value1 target value 1
    /// @param _value2 target value 2
    /// @param _utcPayKey utcpay identification
    function createUtcPayProposal(address _merKey, uint8 _proposalType, address _target, uint256 _value,uint256 _value1, uint256 _value2, address _utcPayKey, uint256 _proposalId) 
        external
        onlyUtcPayManager(_utcPayKey) 
    {
        /// Allowed proposal types
        onlyUtcPayProposalType(_proposalType);

        /// Admin proposal, judging the administrator and whether there is a quantity
        if (_proposalType == uint8(MultiSig.ProposalType.AddUtcPayManager)){
            require(!Managers[_utcPayKey][_target].isManager,"agentManager is registered");
        } else if(_proposalType == uint8(MultiSig.ProposalType.RmUtcPayManager)){
            require(Managers[_utcPayKey][_target].isManager, "agentManager not registered");
            require(managerConfigs[_utcPayKey].managerNumber > 3, "Manager cannot be less than three");
        }

        /// There are two methods here. The two methods have different record lists and different voting administrators.
        /// 1 utcpay votes for its own proposal is the utcpay administrator
        /// 2 utcpay's proposal to the merchant The vote is the multi-signature administrator of the merchant's cold contract corresponding to the merchant's logo
        
        if(_proposalType == uint8(MultiSig.ProposalType.FeeRatio)){
            /// Fee percentage
            require(coldProposals[_merKey][_proposalId].endTime == 0, "The current proposal id exists");
            MultiSig.ProposalData memory args = MultiSig.ProposalData({
                key: _merKey,
                targetKey: address(0),
                endTime:0,
                proposalType: _proposalType,
                target: _target,
                value: _value,
                value1: _value1,
                value2: _value2,
                minVoteRatio: 0,
                voteCount: 0
            });
            _createProposal(args, _proposalId);
        }else{
            require(proposals[_utcPayKey][_proposalId].endTime == 0, "The current proposal id exists");
            uint256 endTime = block.timestamp + VOTE_DURATION;
            MultiSig.ProposalData memory data = MultiSig.ProposalData({
                key: _utcPayKey,
                targetKey: _merKey,
                endTime: endTime,
                proposalType: _proposalType,
                target: _target,
                value: _value,
                value1: 0,
                value2: 0,
                minVoteRatio: MIN_VOTE_RATIO,
                voteCount: 1
            });

            proposals.createProposal(data, _proposalId);
            /// Initiate a proposal to add the current address voting record to the vote by default
            confirmations[_utcPayKey][_proposalId][msg.sender] = true;
            emit ProposalCreated(_proposalId);
        }
    }


    function _createProposal(MultiSig.ProposalData memory args, uint256 _proposalId) internal {
        (address balanceManager,,,,,uint256 minVoteRatio,uint256 voteDuration) = IMerchantConfigExt(configExtAddr).getMerchantData(args.key);
        require(balanceManager != address(0), "Not an merchant");

        MultiSig.ProposalData memory data = MultiSig.ProposalData({
            key: args.key,
            targetKey: args.targetKey,
            endTime: block.timestamp + voteDuration,
            proposalType: args.proposalType,
            target: args.target,
            value: args.value,
            value1: args.value1,
            value2: args.value2,
            minVoteRatio: minVoteRatio,
            voteCount: args.voteCount
        });

        coldProposals.createProposal(data, _proposalId);

        if(args.voteCount > 0){
            /// Initiate a proposal to add the current address voting record to the vote by default
            coldConfirmations[args.key][_proposalId][msg.sender] = true;
        }
        emit ProposalCreated(_proposalId);
    }

    /// @dev cold contract administrator vote
    /// @param _merKey Merchant ID
    /// @param _proposalId proposal id  
    function coldVotes(address _merKey, uint256 _proposalId)
        external
        onlyColdManager(_merKey)
        onlyColdVoted(_merKey, _proposalId)
    {
        MultiSig.Proposal storage proposal = coldProposals[_merKey][_proposalId];
        onlyColdProposalType(proposal.proposalType);

        coldConfirmations[_merKey][_proposalId][msg.sender] = true;
        uint256 managerNumber = coldManagerConfigs[_merKey].managerNumber;
        bool status = _votes(_merKey, _proposalId, managerNumber, proposal);
        emit ColdVotesResult(status);
    }
    

    /// @dev utcpay manage voting
    /// @param _utcPayKey utcpay identification
    /// @param _proposalId proposal id  
    function utcpayVotes(address _utcPayKey, uint256 _proposalId)
        external
        onlyUtcPayManager(_utcPayKey)
        onlyVoted(_utcPayKey, _proposalId) 
    {
        MultiSig.Proposal storage proposal = proposals[_utcPayKey][_proposalId];
        onlyUtcPayProposalType(proposal.proposalType);
        
        /// Initiate a proposal to add the current address voting record to the vote by default
        confirmations[_utcPayKey][_proposalId][msg.sender] = true;

        /// Get the current number of administrators
        uint256 managerNumber = managerConfigs[_utcPayKey].managerNumber;
        bool status = _votes(_utcPayKey, _proposalId, managerNumber, proposal);
        emit ColdVotesResult(status);
    }
    
    /// @dev internal method voting
    /// @param _key ID
    /// @param _proposalId proposal id
    /// @param proposal proposal data
    function _votes(address _key, uint256 _proposalId, uint256 _managerNumber, MultiSig.Proposal storage proposal) internal returns(bool status){

        /// The current proposal status does not allow voting
        require(proposal.status == false, "The current status does not allow voting");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        proposal.voteCount++;
        emit Voted(_key, _proposalId, msg.sender);

        /// Obtain the number of administrators, determine the proportion of votes passed, and execute the proposal category method
        if (proposal.voteCount*100 >= _managerNumber*proposal.minVoteRatio) {

            MultiSig.ProposalType proposalType =MultiSig.ProposalType(proposal.proposalType);

            if (proposalType == MultiSig.ProposalType.AddColdManager) {
                addColdManager(_key, proposal.target );
            } else if (proposalType == MultiSig.ProposalType.RmColdManager) {
                rmColdManager(_key, proposal.target );
            } else if (proposalType == MultiSig.ProposalType.AddHotManager) {
               IMultiSigHot(hotMulAddr).addManager(_key, proposal.target );
            } else if (proposalType == MultiSig.ProposalType.RmHotManager) {
                IMultiSigHot(hotMulAddr).rmManager(_key, proposal.target );
            } else if (proposalType == MultiSig.ProposalType.HotCoinMaxRatio) {
                /// Set the proportion of hot contract funds for each merchant
                IMerchantConfigExt(configExtAddr).updateHotCoinMaxRatio(_key, proposal.value);
            } else if (proposalType == MultiSig.ProposalType.BalancedTime) {
                /// Balance interval time
                IMerchantConfigExt(configExtAddr).updateBalancedTime(_key, proposal.value);
                merchantLastBalancedTime[_key] = 0;
            } else if (proposalType == MultiSig.ProposalType.MinVoteRatio) {
                /// The voting ratio is more than 50%
                IMerchantConfigExt(configExtAddr).updateMinVoteRatio(_key, proposal.value);
            } else if (proposalType == MultiSig.ProposalType.VoteDuration) {
                /// Vote duration
                IMerchantConfigExt(configExtAddr).updateVoteDuration(_key, proposal.value);
            }else if (proposalType == MultiSig.ProposalType.AddUtcPayManager){
                /// Add utcpay administrator
                addManager(_key, proposal.target );
            }else if (proposalType == MultiSig.ProposalType.RmUtcPayManager){
                /// Delete utcpay administrator
                rmManager(_key, proposal.target );
            }else if (proposalType == MultiSig.ProposalType.FeeRatio){
                /// Handling fee ratio proposal Merchant administrators vote
                IMerchantConfigExt(configExtAddr).updateFee(_key, proposal.value, proposal.value1, proposal.value2);
            }else if (proposalType == MultiSig.ProposalType.FeeUtcPayAddr){
                /// Fee address
                IMerchantConfigExt(configExtAddr).updateFeeUtcPayAddr(proposal.target);
            }else if (proposalType == MultiSig.ProposalType.UpdatePrimAgentAddr){
                /// Modify the merchant's first-level agency contract address
                updPrimAgentAddr(proposal.targetKey, proposal.target);
            }else if (proposalType == MultiSig.ProposalType.UpdateSecAgentAddr){
                /// Modify the merchant's secondary agency contract address
                updSecAgentAddr(proposal.targetKey, proposal.target);
            }

            proposal.status = true;
            emit ProposalExecuted(_key, _proposalId);
            return true;
        }
        
        return proposal.status;
    }


    /// @dev add administrator
    /// @param _utcpayKey administrator key
    /// @param _target target address
    function addManager(address _utcpayKey, address _target ) internal  {
        Managers[_utcpayKey].addManager(_target);
        managerConfigs[_utcpayKey].addManagerNumber(_target);
    }

    /// @dev delete administrator
    /// @param _utcpayKey administrator key
    /// @param _target target address
    function rmManager(address _utcpayKey, address _target )  internal  {
        require(managerConfigs[_utcpayKey].managerNumber > 3 , "Manager cannot be less than three");
        Managers[_utcpayKey].rmManager(_target);
        managerConfigs[_utcpayKey].rmManagerNumber(_target);
    }

    function addColdManager(address _merKey, address _target ) internal  {
        coldManagers[_merKey].addManager(_target);
        coldManagerConfigs[_merKey].addManagerNumber(_target);
    }

    function rmColdManager(address _merKey, address _target )  internal  {
        require(coldManagerConfigs[_merKey].managerNumber > 3 , "Manager cannot be less than three");
        coldManagers[_merKey].rmManager(_target);
        coldManagerConfigs[_merKey].rmManagerNumber(_target);
    }

    /// @dev Each merchant's cold contract administrator balances funds
    /// @param _merKey Merchant ID
    function balanceFunds(address _merKey) external onlyColdManager(_merKey){
        uint256 lastBalancedTime = merchantLastBalancedTime[_merKey];
        uint256 balancedTime = IMerchantConfigExt(configExtAddr).getMerBalancedTime(_merKey);

        require(block.timestamp - lastBalancedTime > balancedTime, "Balance funds interval time limit");

        address payable coldPool = IMerchantConfigExt(configExtAddr).getMerColdPool(_merKey);
        ICold(coldPool).balFundsToHot(_merKey);
        merchantLastBalancedTime[_merKey] = block.timestamp;
    }


    /// @dev add erc20 token address
    /// @param _erc20 token address
    /// @param _utcpayKey utcpay identification
    function addErc20s(address _erc20, address _utcpayKey) external onlyUtcPayManager(_utcpayKey) {
        IMerchantConfigExt(configExtAddr).addErc20s(_erc20);
    }

    function removeErc20(address _erc20, address _utcpayKey) external onlyUtcPayManager(_utcpayKey) {
        IMerchantConfigExt(configExtAddr).removeErc20s(_erc20);
    }

    /// @dev access permission cold contract administrator proposal category
    /// @param _proposalType proposal type
    function onlyColdProposalType(uint8 _proposalType) internal pure {
        require(_proposalType == uint8(MultiSig.ProposalType.AddColdManager)   || _proposalType == uint8(MultiSig.ProposalType.RmColdManager)  ||
                _proposalType == uint8(MultiSig.ProposalType.AddHotManager)    || _proposalType == uint8(MultiSig.ProposalType.RmHotManager)   ||
                _proposalType == uint8(MultiSig.ProposalType.HotCoinMaxRatio)  || _proposalType == uint8(MultiSig.ProposalType.BalancedTime)   ||
                _proposalType == uint8(MultiSig.ProposalType.MinVoteRatio)     || _proposalType == uint8(MultiSig.ProposalType.VoteDuration)   ||
                _proposalType == uint8(MultiSig.ProposalType.FeeRatio), "Proposal type not allowed by cold");
    }

    /// @dev access utcpay admin proposal category
    /// @param _proposalType proposal type
    function onlyUtcPayProposalType(uint8 _proposalType) internal pure {
        require(_proposalType == uint8(MultiSig.ProposalType.AddUtcPayManager)    || _proposalType == uint8(MultiSig.ProposalType.RmUtcPayManager) || 
                _proposalType == uint8(MultiSig.ProposalType.FeeRatio)            || _proposalType == uint8(MultiSig.ProposalType.FeeUtcPayAddr)   || 
                _proposalType == uint8(MultiSig.ProposalType.UpdatePrimAgentAddr) || _proposalType == uint8(MultiSig.ProposalType.UpdateSecAgentAddr) , "Proposal type not allowed");
    }

    /// @dev access authority utcpay administrator
    /// @param _utcPayKey utcpay identification
    modifier onlyUtcPayManager(address _utcPayKey) {
        require(Managers[_utcPayKey][msg.sender].isManager,"Not an utcPayManager");
        _;
    }

    /// @dev access authority merchant cold contract administrator
    /// @param _merKey Merchant ID
    modifier onlyColdManager(address _merKey) {
        require(coldManagers[_merKey][msg.sender].isManager,"Not an ColdManager");
        _;
    }

    /// @dev Whether the access administrator votes
    /// @param _utcpayKey Merchant ID
    /// @param _proposalId proposal id
    modifier onlyVoted(address _utcpayKey, uint256 _proposalId) {
        require(!confirmations[_utcpayKey][_proposalId][msg.sender],"The current account has participated in voting");
        _;
    }

    modifier onlyColdVoted(address _merKey, uint256 _proposalId) {
        require(!coldConfirmations[_merKey][_proposalId][msg.sender],"The current account has participated in voting");
        _;
    }

    modifier mangerLen(uint len){
         require(len >= 3 , "Less than three Manager");
         _;
    }

    function getColdProposal(address _merKey, uint256 _proposalId) external view returns (MultiSig.Proposal memory) {
        return coldProposals[_merKey][_proposalId];
    }

    function getProposal(address _utcpayKey, uint256 _proposalId) external view returns (MultiSig.Proposal memory) {
        return proposals[_utcpayKey][_proposalId];
    }

}