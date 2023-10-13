//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/// @title Merchant hot contract
/// @notice Initial merchant configuration address, merchant configuration data
/// Initial hot contract multi-signature address, permission control
/// Merchant fund storage pool

contract Hot is ReentrancyGuard{

    using SafeERC20 for IERC20;

    /// @dev hot contract multi-signature address
    address public immutable mulHotAddr;

    constructor (address _mulHotAddr) {
         mulHotAddr = _mulHotAddr;
    }

    event TransferLogs(address indexed from,address indexed to,address indexed token,uint256 amount,uint256 order);

    /// @dev hot contract batch transfer
    /// @param _erc20s Multiple ERC20 addresses
    /// @param _to multiple wallet addresses
    /// @param _amounts multiple transfer amounts
    /// @param _orders order id
    function transferErc20(
        address _erc20s,
        address[] memory _to,
        uint256[] memory _amounts,
        uint256 _orders
    ) external onlyOwner nonReentrant {
        for (uint i = 0; i < _to.length; i++) { 
            IERC20(_erc20s).safeTransfer(_to[i], _amounts[i]);
            emit TransferLogs(msg.sender, _to[i], _erc20s, _amounts[i], _orders);
        }
    }

    /// ETH transfer
    function transferEth(
        address[] memory _to,
        uint256[] memory _amounts,
        uint256 _orders
    ) external onlyOwner nonReentrant {
        
        for (uint256 i = 0; i < _to.length; i++) {
            payable(_to[i]).transfer(_amounts[i]);
            emit TransferLogs(msg.sender, _to[i], address(0), _amounts[i], _orders);
        }
    }

    /// @dev access rights hot contract multi-signature
    modifier onlyOwner() {
        require(msg.sender == mulHotAddr, "Only Multisig can call this function");
        _;
    }

    fallback() external payable {}
    receive() external payable {}
}
