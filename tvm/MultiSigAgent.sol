//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./interfaces/MultiSig.sol";
import "./Agent.sol";

/// @title agent multi-sign contract
/// @notice manages all proxy contracts
contract MultiSigAgent{

    using MultiSig for MultiSig.managerConfig;
    using MultiSig for mapping(address => mapping (uint256 => MultiSig.Proposal));
    using MultiSig for mapping(address => MultiSig.Manager);

    uint256 public constant VOTE_DURATION = 86400;
    uint256 public constant MIN_VOTE_RATIO = 60;
    uint256 public constant VALUE = 0;

    /// @dev proxy proposal list
    mapping(address => mapping (uint256 => MultiSig.Proposal)) public  proposals;

    /// @dev Proxy multi-signature administrator information
    mapping(address => MultiSig.managerConfig) public managerConfigs;

    /// @dev The current proposal has been voted on by the admin
    mapping(address => mapping(uint256 => mapping (address => bool))) public confirmations;

    /// @dev is an administrator
    mapping(address => mapping(address => MultiSig.Manager)) public Managers;

    event Voted(address indexed merchant, uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(address indexed merchant, uint256 indexed proposalId);
    event ProposalCreated(uint256 indexed _proposalId);

    /// @dev Initialize proxy information and multi-signature administrator
    /// @param _agentKey Agent ID
    /// @param _manager administrator address
    function createAgent(address _agentKey, address[] memory _manager) external mangerLen(_manager.length) {
        managerConfigs[_agentKey].createManager(_agentKey, _manager);
        /// Initialize the multi-signature administrator for each proxy
        for (uint i = 0; i < _manager.length; i++) {
            Managers[_agentKey].addManager(_manager[i]);
        }
    }

    /// @dev proxy admin proposal
    /// @param _agentKey Agent ID
    /// @param _proposalType proposal type
    /// @param _target target address
    function createAgentProposal(address _agentKey, uint8 _proposalType, address _target,  uint256 _proposalId)
        external
        onlyAgentManager(_agentKey)
        checkProposalId(_agentKey, _proposalId)
    {
        /// Allowed proposal types
        onlyAgentProposalType(_proposalType);

        /// Admin proposal, judging the administrator and whether there is a quantity
        if (_proposalType == uint8(MultiSig.ProposalType.AddAgentManager)){
            require(!Managers[_agentKey][_target].isManager,"agentManager is registered");
        } else if(_proposalType == uint8(MultiSig.ProposalType.RmAgentManager)){
            require(Managers[_agentKey][_target].isManager, "agentManager not registered");
            require(managerConfigs[_agentKey].managerNumber > 3, "Manager cannot be less than three");
        }

        uint256 endTime = block.timestamp + VOTE_DURATION;
        MultiSig.ProposalData memory data = MultiSig.ProposalData({
            //proposalId: _proposalId,
            key: _agentKey,
            targetKey: address(0),
            endTime: endTime,
            proposalType: _proposalType,
            target: _target,
            value:  0,
            value1: 0,
            value2: 0,
            minVoteRatio: MIN_VOTE_RATIO,
            voteCount: 1
        });

        proposals.createProposal(data, _proposalId);
        /// Initiate a proposal to add the current address voting record to the vote by default
        confirmations[_agentKey][_proposalId][msg.sender] = true;
        emit ProposalCreated(_proposalId);
       
    }

    /// @dev proxy admin vote
    /// @param _agentKey Agent ID
    /// @param _proposalId Proposal ID
    function agentVotes(address _agentKey, uint256 _proposalId)
        external
        onlyAgentManager(_agentKey)
        onlyVoted(_agentKey, _proposalId)
    {
        MultiSig.Proposal storage proposal = proposals[_agentKey][_proposalId];

        onlyAgentProposalType(proposal.proposalType);
        
        /// Vote to add the current address voting record
        confirmations[_agentKey][_proposalId][msg.sender] = true;

        /// Get the number of current administrators
        uint256 managerNumber = managerConfigs[_agentKey].managerNumber;

        _votes(_agentKey, _proposalId, managerNumber, proposal);
    }

    /// @dev proxy admin vote
    /// @param _key proxy ID
    /// @param _proposalId Proposal ID
    /// @param _managerNumber number of managers
    /// @param proposal proposal data
    function _votes(address _key, uint256 _proposalId, uint256 _managerNumber, MultiSig.Proposal storage proposal) internal {

        /// The current proposal status does not allow voting and voting timeout
        require(proposal.status == false, "The current status does not allow voting");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        proposal.voteCount++;
        
        /// Obtain the number of administrators, judge the proportion of votes passed, and execute the corresponding operation method
        if (proposal.voteCount*100 >= _managerNumber*proposal.minVoteRatio) {

            MultiSig.ProposalType proposalType =MultiSig.ProposalType(proposal.proposalType);

            if (proposalType == MultiSig.ProposalType.AddAgentManager){
                addManager(_key, proposal.target );
            }else if (proposalType == MultiSig.ProposalType.RmAgentManager){
                rmManager(_key, proposal.target );
            }else if (proposalType == MultiSig.ProposalType.UpdateFeeAddr){
                /// change the data
                Agent(_key).setAgentAddr(payable(proposal.target));
            }

            proposal.status = true;
            emit ProposalExecuted(_key, _proposalId);
        }
        emit Voted(_key, _proposalId, msg.sender);  
    }

    /// @dev Add proxy multi-signature administrator
    function addManager(address _agentKey, address _target ) internal  {
        Managers[_agentKey].addManager(_target);
        managerConfigs[_agentKey].addManagerNumber(_target);
    }

    /// @dev delete proxy multi-signature administrator
    function rmManager(address _agentKey, address _target ) internal  {
        require(managerConfigs[_agentKey].managerNumber > 3 , "Manager cannot be less than three");
        Managers[_agentKey].rmManager(_target);
        managerConfigs[_agentKey].rmManagerNumber(_target);
    }

    /// @dev access authority is proxy multi-signature administrator
    /// @param _agentKey Agent ID
    modifier onlyAgentManager(address _agentKey) {
        require(Managers[_agentKey][msg.sender].isManager,"Not an agentManager");
        _;
    }

    /// @dev access permission whether the current administrator votes
    /// @param _agentKey Agent ID
    /// @param _proposalId proposal id
    modifier onlyVoted(address _agentKey, uint256 _proposalId) {
        require(!confirmations[_agentKey][_proposalId][msg.sender],"The current account has participated in voting");
        _;
    }

    /// @dev access permission proposal category
    /// @param _proposalType proposal type
    function onlyAgentProposalType(uint8 _proposalType) internal pure {
        require(_proposalType == uint8(MultiSig.ProposalType.AddAgentManager) || _proposalType == uint8(MultiSig.ProposalType.RmAgentManager)  || 
                _proposalType == uint8(MultiSig.ProposalType.UpdateFeeAddr), "Proposal type not allowed");
    }

    function getProposal(address _agentKey, uint256 _proposalId) external view returns (MultiSig.Proposal memory) {
        return proposals[_agentKey][_proposalId];
    }

    modifier checkProposalId(address _agentKey, uint256 _proposalId) {
        require(proposals[_agentKey][_proposalId].endTime == 0, "The current proposal id exists");
        _;
    }

    modifier mangerLen(uint len){
         require(len >= 3 , "Less than three Manager");
         _;
    }
    
}