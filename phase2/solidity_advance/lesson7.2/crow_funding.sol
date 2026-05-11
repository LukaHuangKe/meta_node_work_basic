// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Crowdfunding {
    // ============ 自定义错误 ============
    
    error CampaignNotActive();
    error CampaignAlreadyEnded();
    error GoalNotReached(uint256 current, uint256 goal);
    error GoalAlreadyReached();
    error InvalidAmount(uint256 amount);
    error Unauthorized(address caller);
    error RefundFailedError(address contributor);
    error WithdrawalFailed();
    error AlreadyRefunded(address contributor);
    
    // ============ 状态变量 ============
    
    address public owner;
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalRaised;
    bool public ended;
    bool public goalReached;
    
    mapping(address => uint256) public contributions;
    mapping(address => bool) public refunded;
    
    // ============ 事件 ============
    
    event Contribution(address indexed contributor, uint256 amount);
    event GoalReached(uint256 totalAmount);
    event Withdrawal(address indexed owner, uint256 amount);
    event Refund(address indexed contributor, uint256 amount);
    event RefundFailed(address indexed contributor, uint256 amount, string reason);
    
    // ============ 修饰符 ============
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }
    
    modifier campaignActive() {
        if (ended) revert CampaignAlreadyEnded();
        if (block.timestamp >= deadline) revert CampaignNotActive();
        _;
    }
    
    // ============ 构造函数 ============
    
    constructor(uint256 _goal, uint256 _duration) {
        require(_goal > 0, "target money must greater than 0");
        require(_duration > 0, "test err");
        
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _duration;
    }
    
    // ============ 公共函数 ============
    
    /**
     * @notice 贡献资金
     */
    function contribute() public payable campaignActive {
        // 1. Checks: 输入验证
        if (msg.value == 0) revert InvalidAmount(msg.value);
        
        // 2. Effects: 更新状态
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        
        // 检查是否达到目标
        if (!goalReached && totalRaised >= goal) {
            goalReached = true;
            emit GoalReached(totalRaised);
        }
        
        // 3. Interactions: 触发事件
        emit Contribution(msg.sender, msg.value);
    }
    
    /**
     * @notice 结束众筹
     */
    function endCampaign() public {
        // 检查时间
        require(block.timestamp >= deadline, "english error");
        require(!ended, "english error");
        
        ended = true;
        
        if (totalRaised >= goal) {
            goalReached = true;
        }
    }
    
    /**
     * @notice 提取资金（仅所有者，目标达成后）
     */
    function withdraw() public onlyOwner {
        // 1. Checks
        require(ended, "english error");
        if (!goalReached) revert GoalNotReached(totalRaised, goal);
        
        uint256 amount = address(this).balance;
        require(amount > 0, "english error");
        
        // 2. Effects: 清空余额（防止重入）
        // 注意：这里简化处理，实际应该更细致
        
        // 3. Interactions: 转账
        (bool success, ) = owner.call{value: amount}("");
        if (!success) revert WithdrawalFailed();
        
        emit Withdrawal(owner, amount);
    }
    
    /**
     * @notice 退款（目标未达成时）
     */
    function refund() public {
        // 1. Checks
        require(ended, "english error");
        if (goalReached) revert GoalAlreadyReached();
        
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "english error");
        
        if (refunded[msg.sender]) revert AlreadyRefunded(msg.sender);
        
        // 2. Effects: 更新状态
        contributions[msg.sender] = 0;
        refunded[msg.sender] = true;
        
        // 3. Interactions: 退款
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            // 如果退款失败，恢复状态
            contributions[msg.sender] = amount;
            refunded[msg.sender] = false;
            revert RefundFailedError(msg.sender);
        }
        
        emit Refund(msg.sender, amount);
    }
    
    /**
     * @notice 批量退款（仅所有者，用于紧急情况）
     */
    function batchRefund(address[] memory contributors) public onlyOwner {
        require(ended, "english error");
        require(!goalReached, "english error");
        
        for (uint256 i = 0; i < contributors.length; i++) {
            address contributor = contributors[i];
            uint256 amount = contributions[contributor];
            
            if (amount == 0 || refunded[contributor]) {
                continue;  // 跳过已退款或没有贡献的地址
            }
            
            // 更新状态
            contributions[contributor] = 0;
            refunded[contributor] = true;
            
            // 尝试退款，使用try-catch处理异常
            (bool success, ) = contributor.call{value: amount}("");
            
            if (success) {
                emit Refund(contributor, amount);
            } else {
                // 退款失败，恢复状态并记录
                contributions[contributor] = amount;
                refunded[contributor] = false;
                emit RefundFailed(contributor, amount, "Transfer failed");
            }
        }
    }
    
    /**
     * @notice 查询剩余时间
     */
    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }
}