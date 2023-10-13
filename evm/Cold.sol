//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IMerchantConfigExt.sol";
import "./Agent.sol";

/// @title Merchant Cold Contract
/// @notice initialize merchant configuration address, merchant configuration data
/// Initial cold contract multi-signature address permission control
/// Merchant fund storage pool

contract Cold is ReentrancyGuard{

    using SafeERC20 for IERC20;

    /// @dev Merchant configuration template address
    address public immutable configExtAddr;
    /// @dev cold contract multi-signature address
    address public immutable mulColdAddr;

    struct Commission {
        uint256 totalCommission;
        uint256 primCommission;
        uint256 secCommission;
        uint256 utcPayCommission;
        uint256 transBalHot;
    }

    constructor(address _configExtAddr, address _mulColdAddr) {
        configExtAddr = _configExtAddr;
        mulColdAddr   = _mulColdAddr;
    }

    event TransferErc20(address indexed from, address indexed to, address indexed token, uint256 amount);
    event TransferCommissionLogs(address indexed token, uint256 indexed totalCommission,uint256 indexed primCommission,uint256 secCommission,uint256 utcPayCommission);
    
    /// @dev cold contract fund balance to hot contract
    /// @param _merKey Merchant ID
    function balFundsToHot(address _merKey) external onlyOwner nonReentrant {
        
        /// Get the currently supported currencies and balance funds for all currencies
        (address[] memory erc20s, address payable coldPool ,address payable hotPool) = IMerchantConfigExt(configExtAddr).getErc20sAmdMerPool(_merKey);
        /// Get the merchant commission configuration parameter is the current merchant key
        IMerchantConfigExt.MerchantAgentConfigData memory data = IMerchantConfigExt(configExtAddr).getMerAgentConfigData(_merKey);
        /// Get the balance storage ratio of the hot contract
        uint256 hotCoinMaxRatio = IMerchantConfigExt(configExtAddr).getMerMaxRatio(_merKey);

        address primAgentFeeAddr = address(0);
        address secAgentFeeAddr = address(0);

        /// Obtain different commission addresses according to different merchant configurations
        if(data.primAgentAddr!= address(0)){
            primAgentFeeAddr = Agent(data.primAgentAddr).agentFeeAddr();
        }
        if(data.secAgentAddr!= address(0)){
            secAgentFeeAddr = Agent(data.secAgentAddr).agentFeeAddr();
        }

        for(uint i; i<erc20s.length; ++i) {

            /// An erc20 hot contract storage balance
            uint256 hotErc20BalanceOf = IERC20(erc20s[i]).balanceOf(hotPool);
            uint256 coldErc20BalanceOf= IERC20(erc20s[i]).balanceOf(coldPool);
            /// Calculate the balance that needs to be transferred to the hot contract
            uint256 amount = IMerchantConfigExt(configExtAddr).getHotBalanceFunds(hotErc20BalanceOf, coldErc20BalanceOf, hotCoinMaxRatio);
            
            /// Tokens are transferred to the merchant hot contract
            if(amount > 0){

                /// commission amount
                Commission memory commission = _calculateCommission(
                    amount,
                    data.feeRateToUtcPay,
                    data.primAgentProfitPerc,
                    data.secAgentProfitPerc,
                    primAgentFeeAddr,
                    secAgentFeeAddr
                );

                /// The balance funds transferred to the hot contract, after deducting the funds after continuing to pay
                IERC20(erc20s[i]).safeTransfer(hotPool, commission.transBalHot);
                /// transfer fee
                IERC20(erc20s[i]).safeTransfer(data.feeUtcPayAddr, commission.utcPayCommission);
                if(data.primAgentAddr!= address(0)){
                    IERC20(erc20s[i]).safeTransfer(primAgentFeeAddr, commission.primCommission);
                }
                if(data.secAgentAddr!= address(0)){
                    IERC20(erc20s[i]).safeTransfer(secAgentFeeAddr, commission.secCommission);
                }

                emit TransferErc20(msg.sender, hotPool, erc20s[i], commission.transBalHot);
                emit TransferCommissionLogs(erc20s[i], commission.totalCommission, commission.primCommission, commission.secCommission, commission.utcPayCommission);
            }
            
        }

        uint256 hotEthBalances = hotPool.balance;
        uint256 coldEthBalances = coldPool.balance;
        uint256 _amount = IMerchantConfigExt(configExtAddr).getHotBalanceFunds(hotEthBalances, coldEthBalances, hotCoinMaxRatio);
        
        /// Tokens are transferred to the hot contract
        if(_amount > 0){
            Commission memory commission = _calculateCommission(
                _amount,
                data.feeRateToUtcPay,
                data.primAgentProfitPerc,
                data.secAgentProfitPerc,
                primAgentFeeAddr,
                secAgentFeeAddr
            );

            payable(hotPool).transfer(commission.transBalHot);

            payable(data.feeUtcPayAddr).transfer(commission.utcPayCommission);
            if(data.primAgentAddr!= address(0)){
                payable(primAgentFeeAddr).transfer(commission.primCommission);
            }
            if(data.secAgentAddr!= address(0)){
                payable(secAgentFeeAddr).transfer(commission.secCommission);
            }
            emit TransferErc20(msg.sender, hotPool, address(0), commission.transBalHot);
            emit TransferCommissionLogs(address(0), commission.totalCommission, commission.primCommission, commission.secCommission, commission.utcPayCommission);
        }
    }


    /// @dev calculate commission
    function _calculateCommission(
        uint256 _amount,
        uint256 _feeRateToUtcPay,
        uint256 _primAgentProfitPerc,
        uint256 _secAgentProfitPerc,
        address _primAgentFeeAddr,
        address _secAgentFeeAddr
    ) internal pure returns (Commission memory) {
        uint256 totalCommission = (_amount * _feeRateToUtcPay) / 1e4;
        uint256 totalPrimCommission = _primAgentFeeAddr != address(0)?(totalCommission * _primAgentProfitPerc) / 1e2:0;
        uint256 utcPayCommission = totalCommission - totalPrimCommission;

        uint256 secCommission =_primAgentFeeAddr != address(0) && _secAgentFeeAddr != address(0)?(totalPrimCommission * _secAgentProfitPerc) / 1e2:0;
        
        uint256 primCommission = totalPrimCommission - secCommission;
        uint256 transBalHot = _amount - totalCommission;

        return Commission({
            totalCommission: totalCommission,
            primCommission: primCommission,
            secCommission: secCommission,
            utcPayCommission: utcPayCommission,
            transBalHot: transBalHot
        });
    }

    /// @dev access rights cold contract multi-signature
    modifier onlyOwner() {
        require(msg.sender == mulColdAddr, "Only Multisig can call this function");
        _;
    }

    receive() external payable {}

    fallback() external payable {}
}