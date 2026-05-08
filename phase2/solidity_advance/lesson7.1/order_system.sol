// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract OrderSystem {
    enum OrderStatus {Created, Paid, Shipped, Completed, Cancelled}

    // 这里其实还要加个是否存在的字段
    struct Order {
        address buyer;
        uint256 amount;
        OrderStatus status;
        uint createdAt;
        bool exist;
    }

    mapping(uint256 => Order) public orders;
    uint256 public orderCount;

    // 订单创建事件
    event OrderCreated(uint256 indexed orderId, address indexed buyer, uint256 amount, uint256 timeStamp);
    // 订单支付事件
    event OrderPaid(uint256 indexed orderId, address indexed buyer, uint256 amount, uint256 timeStamp);
    // 订单发货事件
    event OrderShipped(uint256 indexed orderId, address indexed buyer, uint256 amount, uint256 timeStamp);
    // 订单完成事件
    event OrderCompleted(uint256 indexed orderId, address indexed buyer, uint256 amount, uint256 timeStamp);
    // 订单取消事件
    event OrderCancelled(uint256 indexed orderId, address indexed buyer, uint256 amount, uint256 timeStamp);

    // 创建订单
    function createOrder() public payable returns (uint256) {
        require(msg.value > 0, "Order amount must be greater than 0");
        uint256 orderId = orderCount++;

        orders[orderId] = Order({
            buyer: msg.sender,
            amount: msg.value,
            status: OrderStatus.Created,
            createdAt: block.timestamp,
            exist: true
        });

        emit OrderCreated(orderId, msg.sender, msg.value, block.timestamp);
        return orderId;
    }

    // 支付订单
    function payOrder(uint256 orderId) public{
        // 这里必须使用storage，使用memory没法更新链上数据
        Order storage order = orders[orderId];
        require(order.exist, "Order does not exist");
        require(order.status == OrderStatus.Created, "Order status must be Created");
        require(order.buyer == msg.sender, "Only buyer can pay");
        order.status = OrderStatus.Paid;
        emit OrderPaid(orderId, msg.sender, order.amount, block.timestamp);
    }

    // 发货
    function shippOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(order.exist, "Order does not exist");
        require(order.status == OrderStatus.Paid, "Order status must be Paid");

        order.status = OrderStatus.Shipped;
        emit OrderShipped(orderId, msg.sender, order.amount, block.timestamp);
    }

    // 确认收货
    function completeOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(order.exist, "Order does not exist");
        require(order.buyer == msg.sender, "Not the buyer");
        require(order.status == OrderStatus.Shipped, "Order not shipped");

        order.status = OrderStatus.Completed;
        emit OrderCompleted(orderId, msg.sender, order.amount, block.timestamp);
    }

    // 取消订单
    function cancelOrder(uint256 orderId) public{
        Order storage order = orders[orderId];
        require(order.exist, "Order does not exist");
        require(order.buyer == msg.sender, "Not the buyer");
        require(order.status == OrderStatus.Created || order.status == OrderStatus.Paid, "Cannot cancel order");

        // 保存退款金额（在修改状态前）
        uint256 refundAmount = order.amount;
        bool wasPaid = (order.status == OrderStatus.Created || order.status == OrderStatus.Paid);
        
        // 更新状态
        order.status = OrderStatus.Cancelled;
        
        // 退款（只在已支付的情况下）
        if(wasPaid) {
            (bool success, ) = payable(order.buyer).call{value: refundAmount}("");
            require(success, "Refund failed");
        }

        emit OrderCancelled(orderId, msg.sender, order.amount, block.timestamp);
    }
}