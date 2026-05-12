// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract SecureTokenWithRoles is AccessControl {
    // 定义角色
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    mapping(address => uint256) public balances;
    
    constructor() {
        // 设置默认管理员
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // 给部署者授予MINTER和BURNER角色
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }
    
    /**
     * @notice 铸造函数
     * @dev 只有MINTER角色可以调用
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        balances[to] += amount;
    }
    
    /**
     * @notice 销毁函数
     * @dev 只有BURNER角色可以调用
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        require(balances[from] >= amount, "Insufficient balance");
        balances[from] -= amount;
    }
}