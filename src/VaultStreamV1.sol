// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {Initializable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract VaultStreamV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // State variables
    uint256 public subscriptionPrice;
    uint256 public subscriptionDuration;

    mapping(address => uint256) public subscriptionExpiry;

    uint256 public totalDeposited;

    // Errors
    error VaultStream__IncorrectPayment(uint256 sent, uint256 required);
    error VaultStream__ZeroAddress();

    // Events
    event Subscribed(address indexed user, uint256 expiryTimestamp);
    event Renewed(address indexed user, uint256 newExpiryTimestamp);

    // Functions
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _price, uint256 _duration) public initializer {
        subscriptionPrice = _price;
        subscriptionDuration = _duration;
        __Ownable_init(msg.sender);
    }

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

    function version() public pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
