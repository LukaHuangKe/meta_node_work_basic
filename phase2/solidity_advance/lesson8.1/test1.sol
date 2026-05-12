// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 目标合约：用于演示三种调用方法的区别
contract Target {
    uint256 public value;
    address public sender;
    
    event ValueChanged(uint256 newValue, address caller);
    
    // 修改状态的函数
    function setValue(uint256 _value) external {
        value = _value;
        sender = msg.sender;
        emit ValueChanged(_value, msg.sender);
    }
    
    // 只读函数
    function getValue() external view returns (uint256) {
        return value;
    }
}

// 调用者合约：对比三种调用方法
contract Caller {
    // 本合约的状态变量
    uint256 public value;
    address public sender;
    
    event CallResult(string method, bool success, uint256 value, address sender);
    
    /**
     * @notice 使用call方法调用
     * @dev call在目标合约的上下文中执行，修改目标合约的状态
     */
    function testCall(address target, uint256 newValue) external {
        // 记录调用前的状态
        uint256 callerValueBefore = value;
        uint256 targetValueBefore = Target(target).value();
        
        // 使用call调用目标合约的setValue函数
        (bool success, ) = target.call(
            abi.encodeWithSignature("setValue(uint256)", newValue)
        );
        require(success, "Call failed");
        
        // 检查状态变化
        uint256 callerValueAfter = value;
        uint256 targetValueAfter = Target(target).value();
        
        // 结论：call修改了目标合约的状态，没有修改调用者的状态
        emit CallResult(
            "call",
            success,
            targetValueAfter,  // 目标合约的值被修改
            Target(target).sender()  // msg.sender是调用者合约
        );
    }
    
    /**
     * @notice 使用delegatecall方法调用
     * @dev delegatecall在调用者的上下文中执行，修改调用者的状态
     */
    function testDelegatecall(address target, uint256 newValue) external {
        // 记录调用前的状态
        uint256 callerValueBefore = value;
        uint256 targetValueBefore = Target(target).value();
        
        // 使用delegatecall调用目标合约的setValue函数
        (bool success, ) = target.delegatecall(
            abi.encodeWithSignature("setValue(uint256)", newValue)
        );
        require(success, "Delegatecall failed");
        
        // 检查状态变化
        uint256 callerValueAfter = value;
        uint256 targetValueAfter = Target(target).value();
        
        // 结论：delegatecall修改了调用者的状态，没有修改目标合约的状态
        emit CallResult(
            "delegatecall",
            success,
            callerValueAfter,  // 调用者的值被修改
            sender  // msg.sender是原始调用者（不是调用者合约）
        );
    }
    
    /**
     * @notice 使用staticcall方法调用
     * @dev staticcall只能调用view/pure函数，不能修改状态
     */
    function testStaticcall(address target) external view returns (uint256) {
        // 使用staticcall调用view函数
        (bool success, bytes memory returnData) = target.staticcall(
            abi.encodeWithSignature("getValue()")
        );
        require(success, "Staticcall failed");
        
        // 解码返回值
        uint256 value = abi.decode(returnData, (uint256));
        
        // 结论：staticcall只读取数据，不修改任何状态
        return value;
    }
}