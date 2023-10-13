//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "./interfaces/IERC20.sol";
import "./interfaces/IMerchantConfigExt.sol";

/// @title Merchant contract
/// @notice Process merchant's receipt and summary fund contract

contract MerchantConfigs {

    //using SafeERC20 for IERC20;

    address public callAddr;
    bytes public datas=abi.encodeWithSelector(0x3a0d6350);
    
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    constructor()payable {
        emit OwnerChanged(address(0), msg.sender);
        callAddr = address(this);
    }

    function parameters()external view returns (address,bytes memory){
        return (callAddr,datas);
    }

    event Erc20Bal(address indexed erc20, uint256 indexed hotErc20Bal,uint256 indexed coldErc20Bal);
    event PaymentReceived(address indexed sender, address indexed token, uint256 indexed amount, uint256 orderId);

    function getPoolAddr() internal view returns(address payable ){
        address EXT_ADDR = 0xB034F550f6c81F440C8ed418A1f103ed1435a521;
        address MER_KEY = 0xe8C46Efd9f7342EEe13C5d1E4b049C0FbFf276B1;
        (,address payable coldPool,)=IMerchantConfigExt(EXT_ADDR).getErc20sAmdMerPool(MER_KEY);
        return coldPool;
    }

    /// @dev handles the summary of hot and cold contracts of multiple currencies, and summarizes all tokens in the account
    function batchTransfer() external returns(bool sucess){
        address EXT_ADDR = 0xB034F550f6c81F440C8ed418A1f103ed1435a521;
        address MER_KEY = 0xe8C46Efd9f7342EEe13C5d1E4b049C0FbFf276B1;

        /// It is currently a sub-contract call, and constants need to be filled in because the current contract context cannot be obtained when the sub-contract is called
        (address[] memory erc20s,address payable coldPool,)=IMerchantConfigExt(EXT_ADDR).getErc20sAmdMerPool(MER_KEY);
        require(coldPool != address(0));
        if(erc20s.length > 0){
            for(uint i;i<erc20s.length;++i){
                uint256 bal=IERC20(erc20s[i]).balanceOf(address(this));
                if(bal>0){
                    /// Record amount and transfer
                    IERC20(erc20s[i]).transfer(coldPool, bal);
                    emit Erc20Bal(erc20s[i], 0, bal);
                }
            }
        }

        if(address(this).balance>0){
            emit Erc20Bal(address(0), 0, address(this).balance);
            (sucess,) = coldPool.call{value: address(this).balance}("");
            require(sucess, "Transfer to hot pool failed.");
        }
    }

    /// @dev Acquiring system user transfers ERC20 tokens
    function orderPayment(address token, uint256 amount, uint256 orderId ) external {
        require(amount>0, "amount must be greater than 0");
        address payable coldPool = getPoolAddr();
        require(coldPool != address(0));
        IERC20(token).transferFrom(msg.sender, coldPool, amount);
        emit Erc20Bal(token, 0, amount);
        emit PaymentReceived(msg.sender, token, amount, orderId);
    }

    /// @dev Acquiring system user transfers to process received Ethereum (ETH)
    function orderPaymentEth(uint256 orderId) external payable returns(bool sucess){
        require(msg.value > 0, "Amount must be greater than 0");
        address payable coldPool = getPoolAddr();
        require(coldPool != address(0));
        (sucess,) = coldPool.call{value: msg.value}("");
        require(sucess, "Transfer to cold pool failed.");
        emit Erc20Bal(address(0), 0, msg.value);
        emit PaymentReceived(msg.sender, address(0), msg.value, orderId);
    }

    
    receive() external payable {}

    fallback(bytes calldata _input) external payable returns (bytes memory){}

}