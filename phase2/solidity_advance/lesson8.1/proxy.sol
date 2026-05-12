// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Implementation {
    address public implementation;  // 必须与Proxy的存储布局匹配
    uint256 public value;
    address public owner;
    
    function setValue(uint256 _value) external {
        value = _value;
        owner = msg.sender;
    }
    
    function getValue() external view returns (uint256) {
        return value;
    }
}

contract Proxy {
    address public implementation;
    uint256 public value;
    address public owner;
    
    constructor(address _implementation) {
        implementation = _implementation;
        owner = msg.sender;
    }
    
    function upgrade(address newImplementation) external {
        require(msg.sender == owner, "Not owner");
        implementation = newImplementation;
    }
    
    fallback() external payable {
        address impl = implementation;
        require(impl != address(0), "Implementation not set");
        
        (bool success, bytes memory returnData) = impl.delegatecall(msg.data);
        
        if (!success) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }
    
    receive() external payable {}
}