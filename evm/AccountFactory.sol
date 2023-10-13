//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

/// @title factory contract
/// @notice is used for contract creation and deployment
import "./interfaces/IMerchantConfigExt.sol";
import "./interfaces/Create2.sol";
import "./interfaces/IMultiSigCold.sol";
import "./interfaces/IMultiSigAgent.sol";

contract AccountFactory{
    address public owner;
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
    }
    function setOwner(address _owner) external {
        require(msg.sender == owner,"onlyOwner");
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @dev modify IMerchantConfigExt contract owner
    function transferOwner(address configExtAddr, address mulColdAddr) external {
        require(msg.sender == owner,"onlyOwner");
        IMerchantConfigExt(configExtAddr).transferOwnership(mulColdAddr);                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               
    }

    /// @dev release account
    function createAccount(
        bytes memory bytecode,
        bytes32 saltHash
    ) public{
        assembly {
            pop(create2(0, add(bytecode, 0x20), mload(bytecode), saltHash))
        }
    }

    /// @dev Batch release contract accounts
    function createAccounts(
        bytes[] memory bytecodes,
        bytes32[] memory saltHashs
    ) external{
        for(uint i;i<saltHashs.length;++i){
            createAccount(bytecodes[i],saltHashs[i]);
        }
    }
    function isContract(address account) public view returns (bool) {
        return account.code.length > 0;
    }

    /// @dev get contract address
    function getAccount(
        bytes memory bytecode,
        bytes32 saltHash
    ) external view returns (address) {
        return Create2.computeAddress(
            saltHash,
            keccak256(bytecode)
        );
    }
    function getHash(
        bytes memory bytecode
    ) public pure returns (bytes32) {
        return  keccak256(bytecode);
    }

    /// @dev Batch transfer 0ETH, used for user batch summarizing fund operation
    function sendZeroETH(address[] memory _to) public {
        for (uint256 i = 0; i < _to.length; i++) {
            (bool success, ) = payable(_to[i]).call{value: 0}("");
            require(success, "Transfer failed.");
        }
    }

    /// @dev Create contract and transfer 0 ETH if recipient is not a contract, otherwise transfer directly
    function createAndTransfers(
        address[] memory _to,
        bytes memory bytecodes,
        bytes32[] memory saltHashs
    ) external {
        for (uint256 i = 0; i < _to.length; i++) {
            createAndTransfer(_to[i], bytecodes, saltHashs[i]);
        }
    }

    function createAndTransfer(
        address _to,
        bytes memory bytecodes,
        bytes32 saltHashs
    ) public {
        if (!isContract(_to)) {
            createAccount(bytecodes,saltHashs);
        }
        (bool success, ) = payable(_to).call{value: 0}("");
        require(success, "Transfer failed."); 
    }

    /// @dev create proxy
    function createAgent(
        bytes memory bytecodes,
        bytes32 saltHashs,
        address _agentKey,
        address[] memory _manager,
        address mulAgentArr
    ) external {
        createAccount(bytecodes,saltHashs);
        /// post Successfully created agent
        IMultiSigAgent(mulAgentArr).createAgent(_agentKey,_manager);
    }

}