// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

contract PaymentSplitter {
    error InvalidPayees();
    error InvalidShare();
    error EmptyDeposit();
    error InvalidRecipient();
    error NothingToWithdraw();
    error TransferFailed();

    uint256 public constant BPS = 10_000;
    address public immutable firstPayee;
    address public immutable secondPayee;
    uint256 public immutable firstShare;
    mapping(address payee => uint256) public credit;

    event Deposited(address indexed payer, uint256 firstAmount, uint256 secondAmount);
    event Withdrawn(address indexed payee, address indexed recipient, uint256 amount);

    constructor(address first, address second, uint256 firstShareBps) {
        if (first == address(0)) revert InvalidPayees();
        if (second == address(0)) revert InvalidPayees();
        if (first == second) revert InvalidPayees();
        if (firstShareBps == 0) revert InvalidShare();
        if (firstShareBps >= BPS) revert InvalidShare();

        firstPayee = first;
        secondPayee = second;
        firstShare = firstShareBps;
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        if (msg.value == 0) revert EmptyDeposit();

        // Split the quotient and remainder to avoid an overflowing intermediate product.
        uint256 firstAmount = (msg.value / BPS) * firstShare + (msg.value % BPS) * firstShare / BPS;
        uint256 secondAmount = msg.value - firstAmount;
        credit[firstPayee] += firstAmount;
        credit[secondPayee] += secondAmount;
        emit Deposited(msg.sender, firstAmount, secondAmount);
    }

    function withdraw(address payable recipient) external {
        if (recipient == address(0)) revert InvalidRecipient();
        uint256 amount = credit[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        credit[msg.sender] = 0;
        emit Withdrawn(msg.sender, recipient, amount);
        (bool sent,) = recipient.call{value: amount}("");
        if (!sent) revert TransferFailed();
    }
}
