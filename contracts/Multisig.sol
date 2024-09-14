// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Multisig {
    uint8 public quorum;
    uint8 public newQuorum;
    uint8 public noOfValidSigners;
    uint256 public txCount;

    struct Transaction {
        uint256 id;
        uint256 amount;
        uint256 timestamp;
        uint256 noOfApprovals;
        address[] transactionSigners;
        address sender;
        address recipient;
        address tokenAddress;
        bool isCompleted;
    }

    mapping(address => bool) public isValidSigner;
    mapping(uint => Transaction) public transactions; // txId -> Transaction
    // signer -> transactionId -> bool (checking if an address has signed)
    mapping(address => mapping(uint256 => bool)) public hasSigned;

    event TransferCreated(
        address indexed sender,
        address indexed recipient,
        address tokenAddress,
        uint256 amount,
        uint256 id
    );
    event TransferApproved(address indexed signer, uint256 indexed trxId);
    event QuorumUpdated(address indexed signer, uint256 indexed trxId);

    constructor(uint8 _quorum, address[] memory _validSigners) {
        require(_validSigners.length > 1, "Few valid signers");
        require(_quorum > 1, "Quorum is too small");

        for (uint256 i = 0; i < _validSigners.length; i++) {
            require(_validSigners[i] != address(0), "Zero address not allowed");
            require(!isValidSigner[_validSigners[i]], "Signer already exists");

            isValidSigner[_validSigners[i]] = true;
        }

        noOfValidSigners = uint8(_validSigners.length);

        if (!isValidSigner[msg.sender]) {
            isValidSigner[msg.sender] = true;
            noOfValidSigners += 1;
        }

        require(
            _quorum <= noOfValidSigners,
            "Quorum greater than valid signers"
        );
        quorum = _quorum;
    }

    function transfer(
        uint256 _amount,
        address _recipient,
        address _tokenAddress
    ) external {
        require(msg.sender != address(0), "Address zero found");
        require(isValidSigner[msg.sender], "Invalid signer");

        require(_amount > 0, "Can't send zero amount");
        require(_recipient != address(0), "Address zero found");
        require(_tokenAddress != address(0), "Address zero found");

        require(
            IERC20(_tokenAddress).balanceOf(address(this)) >= _amount,
            "Insufficient funds!"
        );

        uint256 _txId = txCount + 1;
        Transaction storage trx = transactions[_txId];

        trx.id = _txId;
        trx.amount = _amount;
        trx.timestamp = block.timestamp;
        trx.noOfApprovals += 1;
        trx.sender = msg.sender;
        trx.recipient = _recipient;
        trx.tokenAddress = _tokenAddress;
        trx.transactionSigners.push(msg.sender);

        hasSigned[msg.sender][_txId] = true;
        txCount += 1;

        emit TransferCreated(
            trx.sender,
            trx.recipient,
            trx.tokenAddress,
            trx.amount,
            trx.id
        );
    }

    function approveTx(uint256 _txId) external {
        require(msg.sender != address(0), "Address zero found");

        Transaction storage trx = transactions[_txId];

        require(trx.id != 0, "Invalid tx id");
        require(
            IERC20(trx.tokenAddress).balanceOf(address(this)) >= trx.amount,
            "Insufficient funds!"
        );
        require(!trx.isCompleted, "Transaction already completed");
        require(trx.noOfApprovals < quorum, "Approvals already reached");

        require(isValidSigner[msg.sender], "Not a valid signer");
        require(!hasSigned[msg.sender][_txId], "Can't sign twice");

        hasSigned[msg.sender][_txId] = true;
        trx.noOfApprovals += 1;
        trx.transactionSigners.push(msg.sender);

        if (trx.noOfApprovals == quorum) {
            trx.isCompleted = true;
            IERC20(trx.tokenAddress).transfer(trx.recipient, trx.amount);
        }

        emit TransferApproved(msg.sender, _txId);
    }

    function updateQuorum(uint8 _newQuorum) external {
        require(msg.sender != address(0), "Address zero found");
        require(isValidSigner[msg.sender], "Invalid signer");

        require(
            _newQuorum <= noOfValidSigners,
            "Quorum greater than valid signers"
        );

        uint256 _txId = txCount + 1;
        Transaction storage trx = transactions[_txId];

        trx.id = _txId;
        trx.timestamp = block.timestamp;
        trx.noOfApprovals++;
        trx.sender = msg.sender;
        trx.transactionSigners.push(msg.sender);

        hasSigned[msg.sender][_txId] = true;
        txCount += 1;
        newQuorum = _newQuorum;
    }

    function approveQuorumUpdate(uint256 _txId) external {
        require(msg.sender != address(0), "Address zero found");
        require(isValidSigner[msg.sender], "Invalid signer");

        Transaction storage trx = transactions[_txId];
        require(trx.id != 0, "Invalid tx id");

        require(!trx.isCompleted, "Transaction already completed");
        require(trx.noOfApprovals < quorum, "Approvals already reached");
        require(!hasSigned[msg.sender][_txId], "Can't sign twice");

        hasSigned[msg.sender][_txId] = true;
        trx.noOfApprovals++;
        trx.transactionSigners.push(msg.sender);

        if (trx.noOfApprovals == quorum) {
            trx.isCompleted = true;
            quorum = newQuorum;
        }

        emit QuorumUpdated(msg.sender, _txId);
    }

    // function updateValidSigners() {}

    // function getContractBalance() {}
}
