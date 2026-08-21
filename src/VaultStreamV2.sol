// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {Initializable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract VaultStreamV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // V1 State variables
    uint256 public subscriptionPrice;
    uint256 public subscriptionDuration;

    mapping(address => uint256) public subscriptionExpiry;

    uint256 public totalDeposited;

    // V2 State variables
    mapping(address => uint256) public withdrawableBalance;
    address public feeRecipient;
    uint16 public feeBps;

    // Errors
    error VaultStream__IncorrectPayment(uint256 sent, uint256 required);
    error VaultStream__ZeroAddress();
    error VaultStream__ExceedsMaxFeeBps(uint16 feeBps);
    error VaultStream__NoActiveSubscription();
    error VaultStream__NothingToWithdraw();

    // Events
    event Subscribed(address indexed user, uint256 expiryTimestamp);
    event Renewed(address indexed user, uint256 newExpiryTimestamp);

    // Constructor
    constructor() {
        _disableInitializers();
    }

    // V1 Functions
    function subscribe() external payable {
        if (msg.value != subscriptionPrice) {
            revert VaultStream__IncorrectPayment(msg.value, subscriptionPrice);
        }

        if (!isActive(msg.sender)) {
            uint256 expiryTimestamp = block.timestamp + subscriptionDuration;

            subscriptionExpiry[msg.sender] = expiryTimestamp;

            emit Subscribed(msg.sender, expiryTimestamp);
        } else {
            uint256 expiryTimestamp = subscriptionExpiry[msg.sender] + subscriptionDuration;

            subscriptionExpiry[msg.sender] = expiryTimestamp;

            emit Renewed(msg.sender, expiryTimestamp);
        }

        totalDeposited += msg.value;
    }

    function isActive(address user) public view returns (bool) {
        return subscriptionExpiry[user] > block.timestamp;
    }

    // V2 Functions
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) {
            revert VaultStream__ZeroAddress();
        }

        feeRecipient = _feeRecipient;
    }

    function setFeeBps(uint16 _feeBps) external onlyOwner {
        if (_feeBps > 2000) {
            revert VaultStream__ExceedsMaxFeeBps(_feeBps);
        }

        feeBps = _feeBps;
    }

    function cancelSubscription() external {
        uint256 expiry = subscriptionExpiry[msg.sender];

        if (expiry <= block.timestamp) {
            revert VaultStream__NoActiveSubscription();
        }

        uint256 remainingTime = expiry - block.timestamp;

        uint256 refund = (subscriptionPrice * remainingTime) / subscriptionDuration;

        uint256 fee = (refund * feeBps) / 10_000;

        uint256 userRefund = refund - fee;

        subscriptionExpiry[msg.sender] = 0;
        withdrawableBalance[msg.sender] += userRefund;

        if (fee > 0) {
            (bool success,) = payable(feeRecipient).call{value: fee}("");
            require(success);
        }
    }

    function withdraw() external {
        uint256 amount = withdrawableBalance[msg.sender];

        if (amount == 0) {
            revert VaultStream__NothingToWithdraw();
        }

        withdrawableBalance[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success);
    }

    function version() public pure returns (uint256) {
        return 2;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Storage Gap
    uint256[42] private __gap;
}
