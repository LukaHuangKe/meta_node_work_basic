// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }
    
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    
    bool private locked;
    
    modifier noReentrant() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }
    
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }
    
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        required = _required;
    }
    
    function submit(address _to, uint256 _value, bytes memory _data) 
        external 
        onlyOwner 
        returns (uint256) 
    {
        uint256 txId = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        }));
        return txId;
    }
    
    function confirm(uint256 _txId) external onlyOwner {
        require(!confirmations[_txId][msg.sender], "Already confirmed");
        confirmations[_txId][msg.sender] = true;
        transactions[_txId].confirmations += 1;
    }
    
    function execute(uint256 _txId) external onlyOwner noReentrant {
        Transaction storage txInfo = transactions[_txId];
        require(!txInfo.executed, "Already executed");
        require(txInfo.confirmations >= required, "Insufficient confirmations");
        
        txInfo.executed = true;
        
        // 使用Gas限制
        (bool success, ) = txInfo.to.call{gas: 50000, value: txInfo.value}(txInfo.data);
        require(success, "Execution failed");
    }
}