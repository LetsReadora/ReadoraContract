// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ReadoraRewards
 * @dev Smart contract for managing Readora platform rewards, task claims, and daily check-ins
 * @notice Uses EIP712 for off-chain signing and on-chain verification
 */
contract ReadoraRewards is Ownable, EIP712, ReentrancyGuard {
    using ECDSA for bytes32;

    // ============================================================================
    // Constants
    // ============================================================================

    bytes32 public constant CLAIM_TASK_TYPEHASH =
        keccak256("ClaimTask(address user,uint256 taskId,string taskName,uint256 points,uint256 nonce)");

    bytes32 public constant DAILY_CHECKIN_TYPEHASH =
        keccak256("DailyCheckIn(address user,uint256 nonce)");

    // ============================================================================
    // State Variables
    // ============================================================================

    address public backendSigner;
    uint256 public pointsPerTask = 100;
    uint256 public pointsPerCheckIn = 100;
    uint256 public checkInCooldown = 24 hours;

    /// @dev Maps user address to their total points
    mapping(address => uint256) public userPoints;

    /// @dev Maps user => taskId => claimed status
    mapping(address => mapping(uint256 => bool)) public taskClaimed;

    /// @dev Maps user => last check-in timestamp
    mapping(address => uint256) public lastCheckIn;

    /// @dev Maps user => nonce for transaction ordering
    mapping(address => uint256) public userNonce;

    // ============================================================================
    // Events
    // ============================================================================

    event TaskClaimed(
        address indexed user,
        uint256 indexed taskId,
        string taskName,
        uint256 points,
        uint256 timestamp
    );

    event CheckedIn(
        address indexed user,
        uint256 points,
        uint256 timestamp
    );

    event BackendSignerUpdated(address indexed newSigner);
    event PointsPerTaskUpdated(uint256 newAmount);
    event PointsPerCheckInUpdated(uint256 newAmount);
    event CheckInCooldownUpdated(uint256 newCooldown);

    // ============================================================================
    // Modifiers
    // ============================================================================

    modifier validSignature(bytes calldata signature) {
        require(signature.length == 65, "Invalid signature length");
        _;
    }

    // ============================================================================
    // Constructor
    // ============================================================================

    /**
     * @dev Initializes the contract with backend signer address
     * @param _backendSigner Address of the backend wallet that signs transactions
     */
    constructor(address _backendSigner) EIP712("ReadoraRewards", "1") Ownable(msg.sender) {
        require(_backendSigner != address(0), "Invalid backend signer");
        backendSigner = _backendSigner;
    }

    // ============================================================================
    // Task Claiming Functions
    // ============================================================================

    /**
     * @dev Claims a task and awards points to the user
     * @param taskId Unique identifier for the task
     * @param taskName Name of the task (for verification)
     * @param points Points to be awarded
     * @param signature Backend's EIP712 signature
     * @return success Whether the task was successfully claimed
     */
    function claimTask(
        uint256 taskId,
        string calldata taskName,
        uint256 points,
        bytes calldata signature
    ) external nonReentrant validSignature(signature) returns (bool) {
        require(points > 0, "Points must be greater than 0");
        require(!taskClaimed[msg.sender][taskId], "Task already claimed");

        // Verify signature using current nonce
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(
                CLAIM_TASK_TYPEHASH,
                msg.sender,
                taskId,
                keccak256(abi.encodePacked(taskName)),
                points,
                userNonce[msg.sender]
            ))
        );

        address signer = digest.recover(signature);
        require(signer == backendSigner, "Invalid signature");

        // Increment nonce (prevents replay attacks)
        userNonce[msg.sender]++;

        // Mark task as claimed and award points
        taskClaimed[msg.sender][taskId] = true;
        userPoints[msg.sender] += points;

        emit TaskClaimed(msg.sender, taskId, taskName, points, block.timestamp);
        return true;
    }

    // ============================================================================
    // Check-In Functions
    // ============================================================================

    /**
     * @dev Records a daily check-in for the user
     * @param signature Backend's EIP712 signature
     * @return success Whether the check-in was successful
     */
    function dailyCheckIn(
        bytes calldata signature
    ) external nonReentrant validSignature(signature) returns (bool) {
        require(
            block.timestamp >= lastCheckIn[msg.sender] + checkInCooldown,
            "Already checked in today"
        );

        // Verify signature using current nonce
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(
                DAILY_CHECKIN_TYPEHASH,
                msg.sender,
                userNonce[msg.sender]
            ))
        );

        address signer = digest.recover(signature);
        require(signer == backendSigner, "Invalid signature");

        // Increment nonce (prevents replay attacks)
        userNonce[msg.sender]++;

        // Update check-in and award points
        lastCheckIn[msg.sender] = block.timestamp;
        userPoints[msg.sender] += pointsPerCheckIn;

        emit CheckedIn(msg.sender, pointsPerCheckIn, block.timestamp);
        return true;
    }

    // ============================================================================
    // View Functions
    // ============================================================================

    /**
     * @dev Returns the total points for a user
     * @param user Address of the user
     * @return Total points accumulated
     */
    function getUserPoints(address user) external view returns (uint256) {
        return userPoints[user];
    }

    /**
     * @dev Checks if a user has claimed a specific task
     * @param user Address of the user
     * @param taskId ID of the task
     * @return Whether the task has been claimed
     */
    function isTaskClaimed(address user, uint256 taskId) external view returns (bool) {
        return taskClaimed[user][taskId];
    }

    /**
     * @dev Checks if a user can check in today
     * @param user Address of the user
     * @return Whether the user can check in
     */
    function canCheckInToday(address user) external view returns (bool) {
        return block.timestamp >= lastCheckIn[user] + checkInCooldown;
    }

    /**
     * @dev Returns time until next check-in is available
     * @param user Address of the user
     * @return Seconds until check-in is available (0 if available now)
     */
    function timeUntilNextCheckIn(address user) external view returns (uint256) {
        uint256 nextCheckInTime = lastCheckIn[user] + checkInCooldown;
        if (block.timestamp >= nextCheckInTime) {
            return 0;
        }
        return nextCheckInTime - block.timestamp;
    }

    /**
     * @dev Returns the next nonce for a user
     * @param user Address of the user
     * @return The next nonce value
     */
    function getNextNonce(address user) external view returns (uint256) {
        return userNonce[user];
    }

    // ============================================================================
    // Admin Functions
    // ============================================================================

    /**
     * @dev Updates the backend signer address
     * @param newSigner New backend wallet address
     */
    function setBackendSigner(address newSigner) external onlyOwner {
        require(newSigner != address(0), "Invalid address");
        backendSigner = newSigner;
        emit BackendSignerUpdated(newSigner);
    }

    /**
     * @dev Updates the points awarded per task
     * @param newAmount New points amount
     */
    function setPointsPerTask(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Amount must be greater than 0");
        pointsPerTask = newAmount;
        emit PointsPerTaskUpdated(newAmount);
    }

    /**
     * @dev Updates the points awarded per check-in
     * @param newAmount New points amount
     */
    function setPointsPerCheckIn(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Amount must be greater than 0");
        pointsPerCheckIn = newAmount;
        emit PointsPerCheckInUpdated(newAmount);
    }

    /**
     * @dev Updates the check-in cooldown period
     * @param newCooldown New cooldown in seconds
     */
    function setCheckInCooldown(uint256 newCooldown) external onlyOwner {
        require(newCooldown > 0, "Cooldown must be greater than 0");
        checkInCooldown = newCooldown;
        emit CheckInCooldownUpdated(newCooldown);
    }

    /**
     * @dev Allows owner to manually adjust user points (emergency only)
     * @param user Address of the user
     * @param amount Amount to add (can be negative via subtraction)
     */
    function adjustUserPoints(address user, int256 amount) external onlyOwner {
        if (amount >= 0) {
            userPoints[user] += uint256(amount);
        } else {
            require(userPoints[user] >= uint256(-amount), "Insufficient points");
            userPoints[user] -= uint256(-amount);
        }
    }

    /**
     * @dev Marks a task as claimed without verification (admin override)
     * @param user Address of the user
     * @param taskId ID of the task
     */
    function adminClaimTask(address user, uint256 taskId) external onlyOwner {
        require(!taskClaimed[user][taskId], "Task already claimed");
        taskClaimed[user][taskId] = true;
    }

    /**
     * @dev Resets a user's check-in timestamp (admin override)
     * @param user Address of the user
     */
    function adminResetCheckIn(address user) external onlyOwner {
        lastCheckIn[user] = 0;
    }
}
