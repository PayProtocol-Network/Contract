//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./interfaces/IMerchantConfigExt.sol";
import "./interfaces/IHot.sol";
import "./interfaces/MultiSig.sol";

/// @title hot contract multi-signature
/// @notice Multi-signature management merchant data
contract MultiSigHot{

    using MultiSig for MultiSig.managerConfig;
    using MultiSig for mapping(uint256 => MultiSig.TransferProposal);
    using MultiSig for mapping(address => MultiSig.Manager);

    /// @dev cold contract multi-signature address
    address public multiSigColdAddr;
    /// @dev Merchant configuration template address
    address public configExtAddr; 

    /// @dev list of proposals
    mapping(address => mapping(uint256 => MultiSig.TransferProposal)) public transferProposals;
    
    /// @dev Merchant multi-sign administrator information
    mapping(address => MultiSig.managerConfig) public managerConfigs;

    /// @dev The current proposal has been voted on by the admin
    mapping(address => mapping(uint256 => mapping (address => bool))) public confirmations;

    /// @dev is an administrator
    mapping(address => mapping(address => MultiSig.Manager)) public Managers;

    event Voted(address indexed merchant, uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(address indexed merchant, uint256 indexed proposalId);
    event ProposalCreated(uint256 indexed _proposalId);

    /// @param _multiSigColdAddr cold contract multi-signature address
    /// @param _configExtAddr merchant configuration template contract address
    constructor(address _multiSigColdAddr, address _configExtAddr) {
        configExtAddr = _configExtAddr;
        multiSigColdAddr = _multiSigColdAddr;
    }

    /// @dev Initialize merchant creation with utc administrator
    /// @param _merKey Merchant ID
    /// @param _hotManager hot contract administrator address
    function createHotManager(
        address _merKey, address[] memory _hotManager
    ) external mangerLen(_hotManager.length) {
        require(msg.sender == multiSigColdAddr, "Not multiSigColdAddr");
        managerConfigs[_merKey].createManager(_merKey, _hotManager);

        /// Initialize the multi-signature administrator for each merchant
        for (uint i = 0; i < _hotManager.length; i++) {
            Managers[_merKey].addManager(_hotManager[i]);
        }
    }

    /// @dev Add administrator, cold contract multi-signature call
    /// @param _merKey administrator address
    /// @param _target target address
    function addManager(address _merKey,  address _target ) external {
        require(msg.sender == multiSigColdAddr, "Not multiSigColdAddr");
        Managers[_merKey].addManager(_target);
        managerConfigs[_merKey].addManagerNumber(_target);
    }

    /// @dev delete administrator, cold contract multi-signature call
    /// @param _merKey administrator address
    /// @param _target target address
    function rmManager(address _merKey, address _target ) external  {
        require(msg.sender == multiSigColdAddr, "Not multiSigColdAddr");
        require(managerConfigs[_merKey].managerNumber > 2 , "Manager cannot be less than two");
        Managers[_merKey].rmManager(_target);
        managerConfigs[_merKey].rmManagerNumber(_target);
    }

    /// @dev hot contract manager proposal
    /// @param _merKey Merchant ID
    /// @param _proposalType proposal type
    /// @param _erc20s token address
    /// @param _to receiving address
    /// @param _amounts amount of tokens
    /// @param _orders order id
    function createHotProposal(address _merKey, uint8 _proposalType, address _erc20s, address[] memory _to, uint256[] memory _amounts, uint256 _orders, uint256 _proposalId)
        external
        onlyHotManager(_merKey)
        checkProposalId(_merKey, _proposalId)
    {
        onlyHotProposalType(_proposalType);
        require(_merKey != address(0), "Invalid agent address");
        require(_to.length == _amounts.length, "not valid param");

        (address balanceManager,,,,,,uint256 voteDuration) = IMerchantConfigExt(configExtAddr).getMerchantData(_merKey);
        require(balanceManager != address(0), "Not an merchant");
        
        MultiSig.TransferProposal storage proposal = transferProposals[_merKey][_proposalId];
        proposal.endTime = block.timestamp + voteDuration;
        proposal.proposalType = _proposalType;
        proposal.erc20s = _erc20s;
        proposal.to = _to;
        proposal.amounts = _amounts;
        proposal.orders = _orders;

        /// Initiate a proposal to add the current address voting record to the vote by default
        confirmations[_merKey][_proposalId][msg.sender] = true;
        
        emit ProposalCreated(_proposalId);
    }

    /// @dev hot contract management vote
    /// @param _merKey Merchant ID
    /// @param _proposalId proposal id
    function hotVotes(address _merKey, uint256 _proposalId)
        external
        onlyHotManager(_merKey)
        onlyVoted(_merKey, _proposalId)
    {
        MultiSig.TransferProposal storage proposal = transferProposals[_merKey][_proposalId];
        onlyHotProposalType(proposal.proposalType);

        //require(uint8(MultiSig.ManagerType.Hot) == proposal.managerType, "Management category mismatch");
        require(proposal.status == false, "The current status does not allow voting");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");

        confirmations[_merKey][_proposalId][msg.sender] = true;
        uint256 managerNumber = managerConfigs[_merKey].managerNumber;
        /// The current proposal status does not allow voting
        proposal.voteCount++;

        /// Obtain the number of administrators and determine the proportion of votes passed
        if (proposal.voteCount+1 >= managerNumber) {

            MultiSig.ProposalType proposalType =MultiSig.ProposalType(proposal.proposalType);
            address payable hotPool = IMerchantConfigExt(configExtAddr).getMerHotPool(_merKey);
            proposal.status = true;
            if (proposalType == MultiSig.ProposalType.BatchTransferETH){
                /// Hot contract manages ETH transfer
                IHot(hotPool).transferEth(proposal.to, proposal.amounts, proposal.orders);
            }else if (proposalType == MultiSig.ProposalType.BatchTransferERC20){
                /// Hot contract management ERC20 transfer   
                IHot(hotPool).transferErc20(proposal.erc20s, proposal.to, proposal.amounts, proposal.orders);
            }
            emit ProposalExecuted(_merKey, _proposalId);
        }
        emit Voted(_merKey, _proposalId, msg.sender);
    }

    /// @dev access hot contract admin proposal category
    /// @param _proposalType proposal type
    function onlyHotProposalType(uint8 _proposalType) internal pure {
        require(_proposalType == uint8(MultiSig.ProposalType.BatchTransferETH) || 
                _proposalType == uint8(MultiSig.ProposalType.BatchTransferERC20), "Proposal type not allowed by hot");
    }
    
    function getTransferProposal(address _merKey, uint256 _proposalId) external view returns (MultiSig.TransferProposal memory) {
        return transferProposals[_merKey][_proposalId];
    }

    /// @dev access right hot contract administrator
    /// @param _merKey Merchant ID
    modifier onlyHotManager(address _merKey) {
        require(Managers[_merKey][msg.sender].isManager,"Not an HotManager");
        _;
    }

    /// @dev Whether the access administrator votes
    /// @param _merKey Merchant ID
    /// @param _proposalId proposal id
    modifier onlyVoted(address _merKey, uint256 _proposalId) {
        require(!confirmations[_merKey][_proposalId][msg.sender],"The current account has participated in voting");
        _;
    }

    /// @dev Check if proposal exists
    modifier checkProposalId(address _merKey, uint256 _proposalId) {
        require(transferProposals[_merKey][_proposalId].endTime == 0, "The current proposal id exists");
        _;
    }

    modifier mangerLen(uint len){
         require(len >= 2 , "Less than two Manager");
         _;
    }
}