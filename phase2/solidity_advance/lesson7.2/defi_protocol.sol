// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILendingPool {
    function deposit(address asset, uint256 amount) external;
}

interface ISwapRouter {
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256);
}

contract DeFiProtocol {
    
    ILendingPool public lendingPool;
    ISwapRouter public swapRouter;
    
    event StepFailed(string step, string reason);
    
    function complexOperation(
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) public {
        // 步骤1：交换代币
        try swapRouter.swap(tokenIn, tokenOut, amount) returns (uint256 amountOut) {
            // 步骤2：存入借贷池
            try lendingPool.deposit(tokenOut, amountOut) {
                // 全部成功
            } catch Error(string memory reason) {
                emit StepFailed("deposit", reason);
                // 回滚或执行补救措施
            }
        } catch Error(string memory reason) {
            emit StepFailed("swap", reason);
            // 处理交换失败
        }
    }
}