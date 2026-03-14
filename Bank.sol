// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Bank 合约
/// @notice 支持直接转账存款、记录每个地址存款额、管理员提现与前 3 名排行榜
contract Bank {
    /// @notice 前 3 名存款用户结构体
    struct TopDepositor {
        address user; // 用户地址
        uint256 amount; // 累计存款额
    }

    /// @notice 合约管理员（部署者）
    address public owner;
    /// @notice 记录每个地址的累计存款金额
    mapping(address => uint256) public deposits;
    /// @notice 存款金额前 3 名的数组（从高到低）
    TopDepositor[3] public top3;

    /// @notice 存款事件
    event Deposit(address indexed user, uint256 amount, uint256 total);
    /// @notice 管理员提现事件
    event Withdraw(address indexed to, uint256 amount);

    /// @notice 仅管理员可调用的修饰器
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /// @notice 部署时设置管理员为合约部署者
    constructor() {
        owner = msg.sender;
    }

    /// @notice 允许直接转账到合约地址时触发（如 Metamask 直接转账）
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    /// @notice 显式存款方法
    function deposit() external payable {
        _deposit(msg.sender, msg.value);
    }

    /// @notice 管理员提现到指定地址
    /// @param to 提现接收地址
    /// @param amount 提现金额
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid receiver");
        require(amount <= address(this).balance, "Insufficient balance");
        to.transfer(amount);
        emit Withdraw(to, amount);
    }

    /// @notice 内部存款处理：记录存款并更新排行榜
    /// @param user 存款用户
    /// @param amount 存款金额
    function _deposit(address user, uint256 amount) internal {
        require(amount > 0, "Zero deposit");
        deposits[user] += amount;
        _updateTop3(user);
        emit Deposit(user, amount, deposits[user]);
    }

    /// @notice 更新前 3 名排行榜（保持降序）
    /// @param user 需要更新的用户地址
    function _updateTop3(address user) internal {
        uint256 userTotal = deposits[user];
        uint256 index = type(uint256).max;

        // 1) 如果用户已经在榜单中，直接更新其金额
        for (uint256 i = 0; i < 3; i++) {
            if (top3[i].user == user) {
                top3[i].amount = userTotal;
                index = i;
                break;
            }
        }

        // 2) 如果不在榜单中，判断是否能进入前三
        if (index == type(uint256).max) {
            // 当第 3 名已有记录且用户金额不超过第 3 名时，不进入榜单
            if (userTotal <= top3[2].amount && top3[2].user != address(0)) {
                return;
            }
            // 放入第 3 名，再进行冒泡上移
            top3[2] = TopDepositor({user: user, amount: userTotal});
            index = 2;
        }

        // 3) 从更新位置向前冒泡，保持金额降序
        for (uint256 i = index; i > 0; i--) {
            if (top3[i].amount > top3[i - 1].amount) {
                TopDepositor memory tmp = top3[i - 1];
                top3[i - 1] = top3[i];
                top3[i] = tmp;
            } else {
                break;
            }
        }
    }
}
