// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract SHOJIRUToken is ERC20 {
  function mint(address _to, uint256 _amount) public virtual;
}

// For interacting with our own strategy
interface IStrategy {
  // Total want tokens managed by strategy
  function wantLockedTotal() external view returns (uint256);

  // Sum of all shares of users to wantLockedTotal
  function sharesTotal() external view returns (uint256);

  // Main want token compounding function
  function earn() external;

  // Transfer want tokens shojiruFarm -> strategy
  function deposit(address _userAddress, uint256 _wantAmt)
    external
    returns (uint256);

  // Transfer want tokens strategy -> shojiruFarm
  function withdraw(address _userAddress, uint256 _wantAmt)
    external
    returns (uint256);

  function inCaseTokensGetStuck(
    address _token,
    uint256 _amount,
    address _to
  ) external;
}

/** 
@title Shojiru Farm
@notice Contract handling the distribution of the $SHOJIRU token
@dev This is a masterchef contract
@dev "Token per block" variable has been updated to "token per timestamp", to remove the chain-dependancy
**/
contract ShojiruFarm is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Info of each user.
  struct UserInfo {
    uint256 shares; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.

    // We do some fancy math here. Basically, any point in time, the amount of SHOJIRU
    // entitled to a user but is pending to be distributed is:
    //
    //   amount = user.shares / sharesTotal * wantLockedTotal
    //   pending reward = (amount * pool.accSHOJIRUPerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
    //   1. The pool's `accSHOJIRUPerShare` (and `lastRewardTimestamp`) gets updated.
    //   2. User receives the pending reward sent to his/her address.
    //   3. User's `amount` gets updated.
    //   4. User's `rewardDebt` gets updated.
  }

  struct PoolInfo {
    IERC20 want; // Address of the want token.
    uint256 allocPoint; // How many allocation points assigned to this pool. SHOJIRU to distribute per block.
    uint256 lastRewardTimestamp; // Last block number that SHOJIRU distribution occurs.
    uint256 accSHOJIRUPerShare; // Accumulated SHOJIRU per share, times 1e12 to prevent overflow errors. See below.
    address strat; // Strategy address that will SHOJIRU compound want tokens
  }

  address public immutable SHOJIRU;

  address public constant burnAddress =
    0x000000000000000000000000000000000000dEaD;

  uint256 public constant ownerSHOJIRUReward = 100; // 10%

  uint256 public maxSupply = 10_0000_000e18;
  uint256 public ShojiruPerSecond = 1e18; // SHOJIRU tokens created per second
  uint256 public immutable startTime;

  PoolInfo[] public poolInfo; // Info of each pool.
  mapping(IERC20 => bool) public availableAssets; // Info of each pool.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
  uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(
    address indexed user,
    uint256 indexed pid,
    uint256 amount
  );
  event SetAllocPoint(
    uint256 indexed _pid,
    uint256 _oldAllocPoint,
    uint256 _allocPoint
  );
  event SetMaxSupply(uint256 oldSupply, uint256 newSupply);
  event SetShojiruPerSecond(
    uint256 oldShojiruPerSecond,
    uint256 ShojiruPerSecond
  );

  /// @dev Use unix timestamp (not JS)
  constructor(address _shojiru, uint256 _startTime) public {
    SHOJIRU = _shojiru;
    startTime = _startTime;
  }

  /// @notice Get the amount of farmable pools
  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  /// @notice Get reward multiplier over the given _from to _to timestamp.
  function getMultiplier(uint256 _from, uint256 _to)
    public
    view
    returns (uint256)
  {
    if (IERC20(SHOJIRU).totalSupply() >= maxSupply) {
      return 0;
    }
    return _to.sub(_from);
  }

  /// @notice View function to see pending SHOJIRU on frontend.
  function pendingSHOJIRU(uint256 _pid, address _user)
    external
    view
    returns (uint256)
  {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accSHOJIRUPerShare = pool.accSHOJIRUPerShare;
    uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
    if (block.number > pool.lastRewardTimestamp && sharesTotal != 0) {
      uint256 multiplier = getMultiplier(
        pool.lastRewardTimestamp,
        block.number
      );
      uint256 SHOJIRUReward = multiplier
        .mul(ShojiruPerSecond)
        .mul(pool.allocPoint)
        .div(totalAllocPoint);
      accSHOJIRUPerShare = accSHOJIRUPerShare.add(
        SHOJIRUReward.mul(1e12).div(sharesTotal)
      );
    }
    return user.shares.mul(accSHOJIRUPerShare).div(1e12).sub(user.rewardDebt);
  }

  /// @notice View function to see user's staked tokens on frontend.
  function stakedWantTokens(uint256 _pid, address _user)
    external
    view
    returns (uint256)
  {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];

    uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
    uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
    if (sharesTotal == 0) {
      return 0;
    }
    return user.shares.mul(wantLockedTotal).div(sharesTotal);
  }

  /// @notice Update reward variables for all pools. Be careful of gas spending!
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  /** @notice Update reward variables of the given pool to be up-to-date.
   * @dev This is usually called by the contract itself
   * @param _pid Pool Id
   **/
  function updatePool(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    if (block.timestamp <= pool.lastRewardTimestamp) {
      return;
    }
    uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
    if (sharesTotal == 0) {
      pool.lastRewardTimestamp = block.timestamp;
      return;
    }
    uint256 multiplier = getMultiplier(
      pool.lastRewardTimestamp,
      block.timestamp
    );
    if (multiplier <= 0) {
      return;
    }
    uint256 SHOJIRUReward = multiplier
      .mul(ShojiruPerSecond)
      .mul(pool.allocPoint)
      .div(totalAllocPoint);

    SHOJIRUToken(SHOJIRU).mint(
      owner(),
      SHOJIRUReward.mul(ownerSHOJIRUReward).div(1000)
    );
    SHOJIRUToken(SHOJIRU).mint(address(this), SHOJIRUReward);

    pool.accSHOJIRUPerShare = pool.accSHOJIRUPerShare.add(
      SHOJIRUReward.mul(1e12).div(sharesTotal)
    );
    pool.lastRewardTimestamp = block.timestamp;
  }

  /**@notice Deposit funds to the chosen pool (pid)
   * @param _pid Pool Id number
   * @param _wantAmt Amount of deposited tokens
   **/
  function deposit(uint256 _pid, uint256 _wantAmt) external nonReentrant {
    updatePool(_pid);
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    if (user.shares > 0) {
      uint256 pending = user.shares.mul(pool.accSHOJIRUPerShare).div(1e12).sub(
        user.rewardDebt
      );
      if (pending > 0) {
        safeSHOJIRUTransfer(msg.sender, pending);
      }
    }
    if (_wantAmt > 0) {
      pool.want.safeTransferFrom(address(msg.sender), address(this), _wantAmt);

      pool.want.safeIncreaseAllowance(pool.strat, _wantAmt);
      uint256 sharesAdded = IStrategy(poolInfo[_pid].strat).deposit(
        msg.sender,
        _wantAmt
      );
      user.shares = user.shares.add(sharesAdded);
    }
    user.rewardDebt = user.shares.mul(pool.accSHOJIRUPerShare).div(1e12);
    emit Deposit(msg.sender, _pid, _wantAmt);
  }

  /**@notice Withdraw funds to the chosen pool (pid)
   * @param _pid Pool Id number
   * @param _wantAmt Amount of deposited tokens
   **/
  function withdraw(uint256 _pid, uint256 _wantAmt) public nonReentrant {
    updatePool(_pid);

    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
    uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();

    require(user.shares > 0, "user.shares is 0");
    require(sharesTotal > 0, "sharesTotal is 0");

    // Withdraw pending SHOJIRU
    uint256 pending = user.shares.mul(pool.accSHOJIRUPerShare).div(1e12).sub(
      user.rewardDebt
    );
    if (pending > 0) {
      safeSHOJIRUTransfer(msg.sender, pending);
    }

    // Withdraw want tokens
    uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
    if (_wantAmt > amount) {
      _wantAmt = amount;
    }
    if (_wantAmt > 0) {
      uint256 sharesRemoved = IStrategy(poolInfo[_pid].strat).withdraw(
        msg.sender,
        _wantAmt
      );

      if (sharesRemoved > user.shares) {
        user.shares = 0;
      } else {
        user.shares = user.shares.sub(sharesRemoved);
      }

      uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
      if (wantBal < _wantAmt) {
        _wantAmt = wantBal;
      }
      pool.want.safeTransfer(address(msg.sender), _wantAmt);
    }
    user.rewardDebt = user.shares.mul(pool.accSHOJIRUPerShare).div(1e12);
    emit Withdraw(msg.sender, _pid, _wantAmt);
  }

  function withdrawAll(uint256 _pid) external nonReentrant {
    withdraw(_pid, uint256(-1));
  }

  /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
  /// @param _pid Pool Id
  function emergencyWithdraw(uint256 _pid) external nonReentrant {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
    uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();
    uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);

    IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, amount);

    pool.want.safeTransfer(address(msg.sender), amount);
    emit EmergencyWithdraw(msg.sender, _pid, amount);
    user.shares = 0;
    user.rewardDebt = 0;
  }

  // Safe SHOJIRU transfer function, just in case if rounding error causes pool to not have enough
  function safeSHOJIRUTransfer(address _to, uint256 _SHOJIRUAmt) internal {
    uint256 SHOJIRUBal = IERC20(SHOJIRU).balanceOf(address(this));
    bool transferSuccess = false;

    if (_SHOJIRUAmt > SHOJIRUBal) {
      transferSuccess = IERC20(SHOJIRU).transfer(_to, SHOJIRUBal);
    } else {
      transferSuccess = IERC20(SHOJIRU).transfer(_to, _SHOJIRUAmt);
    }

    require(transferSuccess, "safeSHOJIRUTransfer: transfer failed");
  }

  /*
        ------------------------------------
                Governance functions
        ------------------------------------
    */

  /**@notice Add a new lp to the pool. Can only be called by the owner.
   * @dev XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. (Only if want tokens are stored here.)
   * @param _allocPoint Allocation points. weight of the pool = allocPoints/totalAllocPoint
   * @param _want Token address
   * @param _withUpdate Since adding more alloc points will increase totalAllocPoints, we can update the weight of all pools. Or not.
   * @param _strat The start is the address of the start that will hold the tokens
   **/
  function addPool(
    uint256 _allocPoint,
    IERC20 _want,
    bool _withUpdate,
    address _strat
  ) external onlyOwner {
    require(!availableAssets[_want], "Can't add another pool of same asset");
    if (_withUpdate) {
      massUpdatePools();
    }
    uint256 lastRewardTimestamp = block.timestamp > startTime
      ? block.timestamp
      : startTime;
    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(
      PoolInfo({
        want: _want,
        allocPoint: _allocPoint,
        lastRewardTimestamp: lastRewardTimestamp,
        accSHOJIRUPerShare: 0,
        strat: _strat
      })
    );
    availableAssets[_want] = true;
  }

  /**@notice Update the given pool's SHOJIRU allocation point. Can only be called by the owner.
   * @param _pid Pool id
   * @param _allocPoint Weight of the pool
   * @param _withUpdate Should we update the other pools?
  **/
  function set(
    uint256 _pid,
    uint256 _allocPoint,
    bool _withUpdate
  ) external onlyOwner {
    if (_withUpdate) {
      massUpdatePools();
    }

    uint256 oldAllocPoint = poolInfo[_pid].allocPoint;

    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
      _allocPoint
    );

    poolInfo[_pid].allocPoint = _allocPoint;

    emit SetAllocPoint(_pid, oldAllocPoint, _allocPoint);
  }

  /**@notice Set the maximum supply of tokens minted
   * @param _maxSupply maximum supply
  **/
  function setMaxSupply(uint256 _maxSupply) public onlyOwner {
    uint256 oldMaxSupply = maxSupply;

    maxSupply = _maxSupply;

    emit SetMaxSupply(oldMaxSupply, maxSupply);
  }

  function setShojiruPerSecond(uint256 _ShojiruPerSecond) public onlyOwner {
    uint256 oldShojiruPerSecond = ShojiruPerSecond;

    ShojiruPerSecond = _ShojiruPerSecond;

    emit SetShojiruPerSecond(oldShojiruPerSecond, ShojiruPerSecond);
  }

  function inCaseTokensGetStuck(address _token, uint256 _amount)
    external
    onlyOwner
  {
    require(_token != SHOJIRU, "!safe");
    IERC20(_token).safeTransfer(msg.sender, _amount);
  }
}
