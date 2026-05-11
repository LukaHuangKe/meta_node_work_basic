// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// Oracle：预言机
// 预言机是连接区块链和现实世界的桥梁，把链下数据（如股票价格、天气、比赛结果）安全地传输到链上智能合约。
interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

contract LendingProtocol {
    // 自定义错误
    error InsufficientCollateral(uint256 provided, uint256 required);
    error LoanNotFound(uint256 loanId);
    error Unauthorized();
    error TokenTransferFailed();
    error PriceOracleFailed();
    error CollateralRatioTooLow();
    
    struct Loan {
        address borrower;
        address collateralToken;
        address borrowToken;
        uint256 collateralAmount;
        uint256 borrowAmount;
        bool active;
    }
    
    mapping(uint256 => Loan) public loans;
    uint256 public loanCount;
    
    IPriceOracle public priceOracle;
    uint256 public constant COLLATERAL_RATIO = 150; // 150%
    
    event LoanCreated(uint256 indexed loanId, address indexed borrower);
    event LoanRepaid(uint256 indexed loanId);
    event CollateralLiquidated(uint256 indexed loanId);
    
    constructor(address _priceOracle) {
        priceOracle = IPriceOracle(_priceOracle);
    }
    
    /**
     * @notice 创建贷款，意思是合约把借给msg.sender
     */
    function createLoan(
        address collateralToken, //抵押地址
        address borrowToken, //
        uint256 collateralAmount,
        uint256 borrowAmount
    ) public returns (uint256) {
        // 获取价格（使用try-catch处理预言机调用）
        uint256 collateralPrice;
        uint256 borrowPrice;
        
        try priceOracle.getPrice(collateralToken) returns (uint256 price) {
            collateralPrice = price;
        } catch {
            revert PriceOracleFailed();
        }
        
        try priceOracle.getPrice(borrowToken) returns (uint256 price) {
            borrowPrice = price;
        } catch {
            revert PriceOracleFailed();
        }
        
        // 计算抵押价值
        uint256 collateralValue = collateralAmount * collateralPrice;
        uint256 borrowValue = borrowAmount * borrowPrice;
        uint256 requiredCollateral = (borrowValue * COLLATERAL_RATIO) / 100;
        
        // 检查抵押率
        if (collateralValue < requiredCollateral) {
            revert InsufficientCollateral(collateralValue, requiredCollateral);
        }
        
        // 转移抵押物（使用try-catch）
        try IERC20(collateralToken).transferFrom(
            msg.sender,
            address(this),
            collateralAmount
        ) returns (bool success) {
            if (!success) revert TokenTransferFailed();
        } catch {
            revert TokenTransferFailed();
        }
        
        // 创建贷款
        uint256 loanId = loanCount++;
        loans[loanId] = Loan({
            borrower: msg.sender,
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            active: true
        });
        
        // 发放借款
        try IERC20(borrowToken).transfer(msg.sender, borrowAmount) returns (bool success) {
            if (!success) {
                // 如果借款发放失败,退还抵押物
                IERC20(collateralToken).transfer(msg.sender, collateralAmount);
                revert TokenTransferFailed();
            }
        } catch {
            // 如果借款发放失败,退还抵押物
            IERC20(collateralToken).transfer(msg.sender, collateralAmount);
            revert TokenTransferFailed();
        }
        
        emit LoanCreated(loanId, msg.sender);
        return loanId;
    }
    
    /**
     * @notice 偿还贷款
     */
    function repayLoan(uint256 loanId) public {
        Loan storage loan = loans[loanId];
        
        // 检查贷款是否存在且活跃
        if (!loan.active) revert LoanNotFound(loanId);
        if (loan.borrower != msg.sender) revert Unauthorized();
        
        // 收回借款
        try IERC20(loan.borrowToken).transferFrom(
            msg.sender,
            address(this),
            loan.borrowAmount
        ) returns (bool success) {
            if (!success) revert TokenTransferFailed();
        } catch {
            revert TokenTransferFailed();
        }
        
        // 返还抵押物
        try IERC20(loan.collateralToken).transfer(
            loan.borrower,
            loan.collateralAmount
        ) returns (bool success) {
            if (!success) {
                // 如果返还失败,退回借款
                IERC20(loan.borrowToken).transfer(msg.sender, loan.borrowAmount);
                revert TokenTransferFailed();
            }
        } catch {
            // 如果返还失败,退回借款
            IERC20(loan.borrowToken).transfer(msg.sender, loan.borrowAmount);
            revert TokenTransferFailed();
        }
        
        loan.active = false;
        emit LoanRepaid(loanId);
    }
}