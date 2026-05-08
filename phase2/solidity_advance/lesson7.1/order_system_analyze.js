// 导入了 ethers.js 库，用于和以太坊区块链进行交互，比如查询事件和区块信息。
const { ethers } = require('ethers');

// 这个类封装了所有与订单合约交互的逻辑。
class OrderSystemAnalyzer {
    /** 
     * provider：连接到以太坊节点的对象（例如 JSON-RPC 提供者）
     * contractAddress：你的订单系统合约的部署地址
     * contractABI：合约的 ABI（用于将合约方法/事件解析为 JavaScript 可调用形式）
     * 内部创建 this.contract 和 this.provider 供后续方法使用。
     * */ 
    constructor(provider, contractAddress, contractABI) {
        this.contract = new ethers.Contract(contractAddress, contractABI, provider);
        this.provider = provider;
    }
    
    // 获取所有订单
    async getAllOrders() {
        // 调用 filters.OrderCreated() 创建一个事件过滤器，用于匹配所有 OrderCreated 事件。
        const filter = this.contract.filters.OrderCreated();
        // 使用 queryFilter 方法从主网第 0 号区块开始搜索，直到最新区块，返回所有匹配的事件。
        const events = await this.contract.queryFilter(filter, 0, 'latest');
        
        /** 
         * 将每个事件转换成更易读的格式：
         * orderId：从 uint256 转为字符串
         * buyer：从地址转换为字符串
         * amount：将 wei 转换为 ether 单位（18 位小数）
         * timestamp：将 Solidity 的 Unix 时间戳（秒）转为 JavaScript 毫秒时间戳，再格式化为本地日期字符串
         * blockNumber：记录订单创建所在的区块号
         */
        // events.map() 是 JavaScript 的数组映射方法，用于遍历数组并将每个元素转换成新形式，返回一个新数组。
        return events.map(event => ({
            orderId: event.args.orderId.toString(),
            buyer: event.args.buyer,
            amount: ethers.utils.formatEther(event.args.amount),
            timestamp: new Date(event.args.timestamp.toNumber() * 1000).toLocaleString(),
            blockNumber: event.blockNumber
        }));
    }
    
    // 获取用户的订单
    async getUserOrders(userAddress) {
        /**
         * OrderCreated 事件有两个索引参数：orderId 和 buyer。
         * 传入 null 表示不限制第一个参数（orderId），第二个参数 userAddress 则只匹配该买家地址的事件。
         */
        const filter = this.contract.filters.OrderCreated(null, userAddress);
        const events = await this.contract.queryFilter(filter, 0, 'latest');
        
        // 逻辑与 getAllOrders 类似，但只返回指定用户的订单信息，且不包含区块号。
        return events.map(event => ({
            orderId: event.args.orderId.toString(),
            amount: ethers.utils.formatEther(event.args.amount),
            timestamp: new Date(event.args.timestamp.toNumber() * 1000).toLocaleString()
        }));
    }
    
    // 获取订单的完整历史
    async getOrderHistory(orderId) {
        const history = [];
        
        // 查询各类事件
        // 定义订单生命周期中可能出现的所有事件类型，并为每种事件创建一个过滤器，限定在 orderId。
        const events = [
            { name: 'OrderCreated', filter: this.contract.filters.OrderCreated(orderId) },
            { name: 'OrderPaid', filter: this.contract.filters.OrderPaid(orderId) },
            { name: 'OrderShipped', filter: this.contract.filters.OrderShipped(orderId) },
            { name: 'OrderCompleted', filter: this.contract.filters.OrderCompleted(orderId) },
            { name: 'OrderCancelled', filter: this.contract.filters.OrderCancelled(orderId) }
        ];
        
        /** 
         *对每种事件执行查询，获取与该订单相关的所有事件。
         * 记录事件类型、区块号、时间戳以及事件的所有参数（通过展开操作符 ...event.args）。
         * 使用 ?. 可选链，避免 timestamp 不存在时报错。
         */ 
        for (const { name, filter } of events) {
            const results = await this.contract.queryFilter(filter, 0, 'latest');
            results.forEach(event => {
                history.push({
                    eventType: name,
                    blockNumber: event.blockNumber,
                    timestamp: event.args.timestamp?.toNumber(), // 在访问可能不存在的属性时，使用可选链操作符可以避免程序报错崩溃
                    ...event.args
                });
            });
        }
        
        // 按按区块号升序排序，让事件按链上发生的顺序排列，便于理解订单的完整流程。
        history.sort((a, b) => a.blockNumber - b.blockNumber);
        return history;
    }
    
    // 统计订单状态
    async getOrderStatistics() {
        // 先获取所有订单的基本信息（仅依据 OrderCreated 事件）。
        const allOrders = await this.getAllOrders();
        
        /** 
         * 统计订单状态的结构。
         * 初始化统计对象，记录总订单数、已创建、已支付、已发货、已完成、已取消订单数。
         * 并累计总订单金额。
         */
        const stats = {
            totalOrders: allOrders.length,
            created: 0,
            paid: 0,
            shipped: 0,
            completed: 0,
            cancelled: 0,
            totalValue: ethers.BigNumber.from(0)
        };
        
        // 统计每个订单的最终状态
        for (const order of allOrders) {
            const orderId = order.orderId;
            
            // 查询订单的所有事件
            const completed = await this.contract.queryFilter(
                this.contract.filters.OrderCompleted(orderId), 0, 'latest'
            );
            const cancelled = await this.contract.queryFilter(
                this.contract.filters.OrderCancelled(orderId), 0, 'latest'
            );
            const shipped = await this.contract.queryFilter(
                this.contract.filters.OrderShipped(orderId), 0, 'latest'
            );
            const paid = await this.contract.queryFilter(
                this.contract.filters.OrderPaid(orderId), 0, 'latest'
            );
            
            // 确定最终状态
            /** 
             * 状态的判断顺序很重要：completed 优先级最高，其次是 cancelled，然后是 shipped，再到 paid，最后是 created。
             * 如果一个订单既有 Completed 又有 Cancelled 事件（异常情况），也只会计入 completed。
             */
            if (completed.length > 0) {
                stats.completed++;
            } else if (cancelled.length > 0) {
                stats.cancelled++;
            } else if (shipped.length > 0) {
                stats.shipped++;
            } else if (paid.length > 0) {
                stats.paid++;
            } else {
                stats.created++;
            }
            
            // 累计总金额
            stats.totalValue = stats.totalValue.add(
                ethers.utils.parseEther(order.amount) //将订单金额（ether 单位）转换为 wei，然后加到总金额中。
            );
        }
        
        /** 
         * 返回统计结果，同时：
         * 将 totalValue 从 wei 转回 ether 单位。
         * 计算平均订单金额（总金额 ÷ 订单数），如果无订单则返回 '0'
         */
        return {
            ...stats, //作用是将 stats 对象的所有属性"展开"到一个新对象中，因为返回的参数很多跟stats的参数一致，不需要每个再写一遍了
            totalValue: ethers.utils.formatEther(stats.totalValue),
            averageOrderValue: stats.totalOrders > 0 
                ? ethers.utils.formatEther(stats.totalValue.div(stats.totalOrders))
                : '0'
        };
    }
}

// 使用示例
async function main() {
    /**
     * 通过本地 8545 端口的以太坊节点连接（常用于本地开发网络，如 Hardhat、Ganache）。
    需要替换 contractAddress 和 contractABI 为实际值。
     */
    const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
    const contractAddress = '0x...';  // 你的合约地址
    const contractABI = ['...'];  // 你的合约ABI
    
    const analyzer = new OrderSystemAnalyzer(provider, contractAddress, contractABI);
    
    // 获取所有订单
    console.log('所有订单:');
    const allOrders = await analyzer.getAllOrders();
    console.table(allOrders);
    
    // 获取特定用户的订单
    const userAddress = '0xYourAddress';
    console.log(`\n用户 ${userAddress} 的订单:`);
    const userOrders = await analyzer.getUserOrders(userAddress);
    console.table(userOrders);
    
    // 获取订单历史
    const orderId = 0;
    console.log(`\n订单 #${orderId} 的历史:`);
    const history = await analyzer.getOrderHistory(orderId);
    console.table(history);
    
    // 统计数据
    console.log('\n订单统计:');
    const stats = await analyzer.getOrderStatistics();
    console.log(stats);
}

// 执行 main 函数，并捕获任何未处理的错误，输出到控制台。
main().catch(console.error);