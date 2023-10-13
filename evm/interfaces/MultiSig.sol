//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;
library MultiSig {

    /// @dev Other proposal transfer data
    struct ProposalData {
        address key;
        address targetKey;
        uint256 endTime;
        uint8 proposalType;
        address target;
        uint256 value;
        uint256 value1;
        uint256 value2;
        uint256 minVoteRatio;
        uint256 voteCount;
    }

    /// @dev transfer proposal transfer data
    struct TransferProposalData {
        address key; 
        uint256 endTime;
        uint8 proposalType;
        address erc20s;
        address[] to;
        uint256[] amounts;
        uint256 orders;
    }

    /// @dev Each proposal initializes the stored information
    struct Proposal {
        /// Proposal start time
        uint256 startTime;
        /// Proposal expiration time
        uint256 endTime;
        /// proposal type
        uint8   proposalType;
        /// Target Merchant ID
        address targetKey;
        /// target address
        address target;
        /// target value
        uint256 value;
        uint256 value1;
        uint256 value2;
        /// Minimum voting ratio
        uint256 minVoteRatio;
        /// Proposal current status
        bool    status;
        /// number of votes
        uint256 voteCount;
    }

    /// @dev The initial storage information for each transfer proposal
    struct TransferProposal {
        //uint256 startTime;
        uint256 endTime;
        uint8   proposalType;
        /// Batch transfer erc20 addresses
        address erc20s;
        /// Batch transfer account address
        address[] to;
        /// The amount of tokens transferred in batches
        uint256[] amounts;
        uint256 orders;
        //uint256 minVoteRatio;
        bool    status;
        uint256 voteCount;
    }

    /// @dev all voting types
    enum ProposalType {
        AddColdManager,  /// Add cold contract administrator (cold contract administrator operation)
        RmColdManager,  /// Delete the cold contract manager
        AddHotManager, /// Add hot contract manager 
        RmHotManager, /// Delete hot contract manager
        HotCoinMaxRatio,   /// Set the proportion of hot contract funds for each merchant
        BalancedTime,     /// Balance interval time
        MinVoteRatio,    /// The voting ratio is more than 50%
        VoteDuration,   /// Vote duration
        AddUtcPayManager, /// Add utcpay administrator (utcpay administrator operation)
        RmUtcPayManager, /// Delete utcpay administrator
        FeeRatio,       /// Handling fee ratio (utcpay proposal cold contract management vote)
        FeeUtcPayAddr, /// Modify the utcPay fee collection address
        BatchTransferETH, /// Hot contract ETH transfer (hot contract operation)
        BatchTransferERC20, /// Hot contract ERC20 transfer
        AddAgentManager,   /// Add proxy administrator (proxy administrator operation)
        RmAgentManager,   /// Delete proxy administrator
        UpdateFeeAddr,   /// Modify the fee collection address
        UpdatePrimAgentAddr, /// Modify the first-level agency contract address
        UpdateSecAgentAddr  /// Modify the address of the secondary agency contract
    }

    /// @dev administrator configures the initial storage information
    struct managerConfig {
        address key; /// key
        uint256 managerNumber; /// Number of administrators
    }

    /// @dev administrator initializes the stored information
    struct Manager {
        bool isManager;
    }

    event CreateChanged(address indexed _key,  address[] indexed _manager);
    event addManagerLog(address indexed _managerAddr);

    /// @dev create management account
    function createManager(MultiSig.managerConfig storage self, address _key, address[] memory _manager) internal {
        require(self.key  == address(0) && _key !=address(0), "key is registered");

        self.key  = _key;
        self.managerNumber  = _manager.length;
        emit CreateChanged(_key, _manager);
    }

    /// @dev add administrator
    function addManager(
        mapping(address => Manager) storage self,
        address _managerAddr
    ) internal {
        require(!self[_managerAddr].isManager, "manager is registered");
        self[_managerAddr].isManager = true;
        emit addManagerLog(_managerAddr);
    }

    /// @dev increase the number of administrators
    function addManagerNumber(
        MultiSig.managerConfig storage self,
        address _managerConfigAddr
    ) internal {
        require(self.key != address(0) && _managerConfigAddr != address(0));
        self.managerNumber++;
    }



    /// @dev delete administrator
    function rmManager(
        mapping(address => Manager) storage self,
        address _managerAddr
    ) internal {
        require(self[_managerAddr].isManager, "manager not registered");
        self[_managerAddr].isManager = false;
    }

    /// @dev delete administrator number
    function rmManagerNumber(
        MultiSig.managerConfig storage self,
        address _managerConfigAddr
    ) internal {
        require(self.key != address(0) && _managerConfigAddr != address(0));
        self.managerNumber--;
    }

    /// @dev create a proposal
    function createProposal(
        mapping(address => mapping(uint256=>MultiSig.Proposal)) storage self,
        ProposalData memory data,
        uint256 _proposalId
    ) internal {
        require(data.key != address(0), "Invalid agent address");
        require(data.proposalType >= uint8(ProposalType.AddColdManager) && data.proposalType <= uint8(ProposalType.UpdateSecAgentAddr), "Invalid proposal type");
        require(data.endTime > block.timestamp, "End time should be greater than current time");

        self[data.key][_proposalId] = Proposal({
            startTime: block.timestamp,
            endTime: data.endTime,
            proposalType: data.proposalType,
            targetKey: data.targetKey,
            target: data.target,
            value: data.value,
            value1: data.value1,
            value2: data.value2,
            minVoteRatio: data.minVoteRatio,
            status: false,
            voteCount: data.voteCount
        });
    }

}