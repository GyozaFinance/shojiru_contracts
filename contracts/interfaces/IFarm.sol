// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IFarm {

    struct PoolInfo {
        address lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. ZAPs to distribute per block.
        uint256 lastRewardTime;  // Last block time that ZAPs distribution occurs.
        uint256 accZAPPerShare; // Accumulated ZAPs per share, times 1e12. See below.
    }

    function poolLength() external view returns (uint256);

    function userInfo(uint256 _pid, address _user) external view returns (uint256);
    function poolInfo(uint256 _pid) external view returns (PoolInfo calldata);

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256);

    // Omnidex interface
    function pendingCharm(uint256 _pid, address _user) external view returns (uint256);

    // Zappy inteface
    function pendingZAP(uint256 _pid, address _user) external view returns (uint256); 

    function zappy() external view returns (address);
    // Deposit LP tokens to MasterChef for CAKE-like allocation.
    function deposit(uint256 _pid, uint256 _amount) external;

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external;

    // Stake CAKE-like tokens to MasterChef
    function enterStaking(uint256 _amount) external;

    // Withdraw CAKE-like tokens from STAKING.
    function leaveStaking(uint256 _amount) external;

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external;
}
