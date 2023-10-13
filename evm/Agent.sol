//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

/// @title proxy contract
contract Agent{
    address  payable public agentFeeAddr;
    address public immutable mulAgentAddr;

    constructor(address payable _agentFeeAddr, address _mulAgentAddr) {
        agentFeeAddr = _agentFeeAddr;
        mulAgentAddr = _mulAgentAddr;
    }

    /// @dev Modify the agency fee address
    /// @param _agentFeeAddr Agent fee address
    function setAgentAddr (address payable _agentFeeAddr) external onlyOwner {
        agentFeeAddr = _agentFeeAddr;
    }

    /// @dev access authority proxy multi-sign contract
    modifier onlyOwner() {
        require(msg.sender == mulAgentAddr, "Only Multisig can call this function");
        _;
    }
}





