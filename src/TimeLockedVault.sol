//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title A Time Locked Vault Contract
 * @author Devarshi Dave
 * @notice This contract allows users to deposit Ether and ERC20 tokens with a time lock.
 */

contract TimeLockedVault{
    //Errors
    error TimeLockedVault__InsufficientDeposit();
    error TimeLockedVault__InvalidUnlockTime();
    error TimeLockedVault__LockNotExpired();
    error TimeLockedVault__InsufficientBalance();
    error TimeLockedVault__NoActiveLock();
    error TimeLockedVault__InvalidToken();

    //Structs
    struct Lock{
        uint256 amount;
        uint256 unlockTime;
    }

    //State Variables
    mapping(address => Lock) public ethLocks;
    mapping(address => mapping(address => Lock)) public tokenLocks; 
    address public owner;

    //Events
    event EthDeposited(address indexed user, uint256 amount, uint256 unlockTime);
    event EthWithdrawn(address indexed user, uint256 amount);
    event LockExtended(address indexed user, uint256 newUnlockTime);
    event TokenDeposited(address indexed user, address indexed token, uint256 amount, uint256 unlockTime);
    event TokenWithdrawn(address indexed user, address indexed token, uint256 amount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    //Modifiers
    modifier onlyOwner(){
         require(msg.sender == owner, "Not owner");
        _;
    }

    //Constructor
    constructor() {
        owner = msg.sender;
    }

    //Fuctions
    //---------------------- ETH Logic -------------------
    function depositEth(uint256 _unlockTime) external payable {
        if(msg.value == 0) {
            revert TimeLockedVault__InsufficientDeposit();
        }
        if(_unlockTime <= block.timestamp) {
            revert TimeLockedVault__InvalidUnlockTime();
        }

        Lock storage userLock = ethLocks[msg.sender];

        if(userLock.amount >0){
            revert TimeLockedVault__LockNotExpired(); 
        }
        ethLocks[msg.sender] = Lock({
            amount: msg.value,
            unlockTime: _unlockTime
        });
       
        emit EthDeposited(msg.sender, msg.value, _unlockTime); 
    }

    function withdrawEth() external {
        Lock memory userLock = ethLocks[msg.sender];
        if(userLock.amount == 0){
            revert TimeLockedVault__InsufficientBalance();
        }
        if(block.timestamp < userLock.unlockTime){
            revert TimeLockedVault__LockNotExpired();
        }

        delete ethLocks[msg.sender];
        (bool success,) = msg.sender.call{value: userLock.amount}("");
        require(success, "Ether transfer failed");

        emit EthWithdrawn(msg.sender, userLock.amount);     
    }

    function extendEthLock(uint256 _newUnlockTime) external {
        Lock storage userLock = ethLocks[msg.sender];
        if(userLock.amount == 0){
            revert TimeLockedVault__NoActiveLock();
        }
        require(_newUnlockTime > userLock.unlockTime, "Must increase unlock time");

        userLock.unlockTime = _newUnlockTime;
        emit LockExtended(msg.sender, _newUnlockTime);
    }

    //---------------------- ERC20 Logic -------------------

    function depositToken(address _token, uint256 _amount, uint256 _unlockTime) external {
        if(_token == address(0)){
            revert TimeLockedVault__InvalidToken();
        }
        if(_amount == 0){
            revert TimeLockedVault__InsufficientDeposit();
        }
         if(_unlockTime <= block.timestamp) {
            revert TimeLockedVault__InvalidUnlockTime();
        }

        Lock storage userLock = tokenLocks[msg.sender][_token];
        if(userLock.amount >0){
            revert TimeLockedVault__LockNotExpired(); 
        }
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");

        tokenLocks[msg.sender][_token] = Lock(_amount, _unlockTime);
        emit TokenDeposited(msg.sender, _token, _amount, _unlockTime);
    }

    function withdrawToken(address _token) external {
        Lock memory userLock = tokenLocks[msg.sender][_token];
        if(userLock.amount == 0){
            revert TimeLockedVault__InsufficientBalance();
        }
        if(block.timestamp < userLock.unlockTime){
            revert TimeLockedVault__LockNotExpired();
        }

        delete tokenLocks[msg.sender][_token];
        bool sucess = IERC20(_token).transfer(msg.sender, userLock.amount);
        require(sucess, "Token transfer failed");

        emit TokenWithdrawn(msg.sender, _token, userLock.amount);
    }

    function extendTokenLock(address _token, uint256 _newUnlockTime) external {
        Lock storage userLock = tokenLocks[msg.sender][_token];
        if(userLock.amount == 0){
            revert TimeLockedVault__NoActiveLock();
        }
        require(_newUnlockTime > userLock.unlockTime, "Must increase unlock time");

        userLock.unlockTime = _newUnlockTime;
        emit LockExtended(msg.sender, _newUnlockTime);
    }

    // ---------------------- Admin -----------------------

    function transferOwnership(address _newOwner) external onlyOwner{
        require(_newOwner != address(0), "Invalid new owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function emergencyWithdraw(address_user, address_token) external onlyOwner{
        if(_token == address(0)){
            Lock memory userLock = ethLocks[_user];
            if(userLock.amount == 0){
                revert TimeLockedVault__InsufficientBalance();
            }
            delete ethLocks[_user];
            (bool success,) = _user.call{value: userLock.amount}("");
            require(success, "Ether transfer failed");
            emit EthWithdrawn(_user, userLock.amount);
        }
        else{
            Lock memory userLock = tokenLocks[_user][_token];
            if(userLock.amount == 0){
                revert TimeLockedVault__InsufficientBalance();
            }
            delete tokenLocks[_user][_token];
            bool success = IERC20(_token).transfer(_user, userLock.amount);
            require(success, "Token transfer failed");
            emit TokenWithdrawn(_user, _token, userLock.amount);
        }
    }

    receive() external payable {
        revert("Use depositETH()");
    }
}