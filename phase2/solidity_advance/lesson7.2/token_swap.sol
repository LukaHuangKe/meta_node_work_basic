// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenSwap {
    event SwapSuccess(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event SwapFailed(address indexed user, string reason);
    event SwapFailedPanic(address indexed user, uint256 errorCode);
    event SwapFailedCustom(address indexed user, bytes errorData);
    
    /**
     * @notice 交换代币
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) public returns (bool) {
        // 步骤1：从用户转入tokenIn
        try IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn) returns (bool success) {
            if (!success) {
                emit SwapFailed(msg.sender, "TransferFrom returned false");
                return false;
            }
            
            // 步骤2：向用户转出tokenOut
            try IERC20(tokenOut).transfer(msg.sender, amountOut) returns (bool success2) {
                if (!success2) {
                    // tokenOut转账失败,退还tokenIn
                    IERC20(tokenIn).transfer(msg.sender, amountIn);
                    emit SwapFailed(msg.sender, "Transfer returned false");
                    return false;
                }
                
                emit SwapSuccess(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
                return true;
                
            } catch Error(string memory reason) {
                // tokenOut转账失败,退还tokenIn
                IERC20(tokenIn).transfer(msg.sender, amountIn);
                emit SwapFailed(msg.sender, reason);
                return false;
            } catch Panic(uint errorCode) {
                // tokenOut转账Panic,退还tokenIn
                IERC20(tokenIn).transfer(msg.sender, amountIn);
                emit SwapFailedPanic(msg.sender, errorCode);
                return false;
            } catch (bytes memory errorData) {
                // tokenOut转账其他错误,退还tokenIn
                IERC20(tokenIn).transfer(msg.sender, amountIn);
                emit SwapFailedCustom(msg.sender, errorData);
                return false;
            }
            
        } catch Error(string memory reason) {
            emit SwapFailed(msg.sender, reason);
            return false;
        } catch Panic(uint errorCode) {
            emit SwapFailedPanic(msg.sender, errorCode);
            return false;
        } catch (bytes memory errorData) {
            emit SwapFailedCustom(msg.sender, errorData);
            return false;
        }
    }
}