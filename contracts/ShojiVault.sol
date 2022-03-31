// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IFarm.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IShojiruVault.sol";

/**
@title ShojiVault
@notice A vault allowing the user to compound the rewards into the native-token pool
**/
contract ShojiVault is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct UserInfo {
    uint256 stake; // How many assets the user has provided.
    uint256 autoShojiruShares; // How many staked $SHOJIRU user had at his last action
    uint256 rewardDebt; // Shojiru shares not entitled to the user
    uint256 lastDepositedTime; // Timestamp of last user deposit
  }

  // Instances
  address public WTLOS; // Wrapped Telos address, used for swapping
  IERC20 public SHOJIRU; // The SHOJIRU token!
  IShojiruVault public immutable AUTO_SHOJIRU; // TODO: Document this
  IERC20 public immutable STAKED_TOKEN; // Token staked in the external pool

  // Runtime data
  mapping(address => UserInfo) public userInfo; // Info of users
  uint256 public accSharesPerStakedToken; // Accumulated AUTO_SHOJIRU shares per staked token, times 1e18.

  // Farm info
  IFarm public immutable STAKED_TOKEN_FARM;
  IERC20 public immutable FARM_REWARD_TOKEN;
  uint256 public immutable FARM_PID;
  bool public immutable IS_CAKE_STAKING;

  // Settings
  IPancakeRouter02 public router;
  address[] public pathToShojiru; // Path from staked token to SHOJIRU
  address[] public pathToWtlos; // Path from staked token to WTLOS

  address public treasury;
  address public keeper;
  uint256 public constant denominator = 1000;
  uint256 public keeperFee = 50; // 0.5%
  uint256 public constant keeperFeeUL = 10; // 1%

  address public platform;
  uint256 public platformFee;
  uint256 public constant platformFeeUL = 50; // 5%

  address public constant BURN_ADDRESS =
    0x000000000000000000000000000000000000dEaD;
  uint256 public buyBackRate;
  uint256 public constant buyBackRateUL = 30; // 3%

  uint256 public earlyWithdrawFee = 5; // 0.5%
  uint256 public constant earlyWithdrawFeeUL = 30; // 3%
  uint256 public constant withdrawFeePeriod = 3 days;

  // Actions
  event Deposit(address indexed user, uint256 amount);
  event Withdraw(address indexed user, uint256 amount);
  event EarlyWithdraw(address indexed user, uint256 amount, uint256 fee);
  event ClaimRewards(address indexed user, uint256 shares, uint256 amount);

  // Setting updates
  event SetPathToShojiru(address[] oldPath, address[] newPath);
  event SetPathToWtlos(address[] oldPath, address[] newPath);
  event SetBuyBackRate(uint256 oldBuyBackRate, uint256 newBuyBackRate);
  event SetTreasury(address oldTreasury, address newTreasury);
  event SetKeeper(address oldKeeper, address newKeeper);
  event SetKeeperFee(uint256 oldKeeperFee, uint256 newKeeperFee);
  event SetPlatform(address oldPlatform, address newPlatform);
  event SetPlatformFee(uint256 oldPlatformFee, uint256 newPlatformFee);
  event SetEarlyWithdrawFee(
    uint256 oldEarlyWithdrawFee,
    uint256 newEarlyWithdrawFee
  );

  constructor(
    address _shojiru,
    address _autoShojiru,
    address _stakedToken,
    address _stakedTokenFarm,
    address _farmRewardToken,
    uint256 _farmPid,
    bool _isCakeStaking, // Is it the single-pool in a PCS fork?
    address _router,
    address[] memory _pathToShojiru,
    address[] memory _pathToWtlos,
    address _owner,
    address _treasury,
    address _keeper,
    address _platform,
    uint256 _buyBackRate,
    uint256 _platformFee
  ) public {
    SHOJIRU = IERC20(_shojiru);

    require(
      _pathToShojiru[0] == address(_farmRewardToken) &&
        _pathToShojiru[_pathToShojiru.length - 1] == address(SHOJIRU),
      "ShojiVault: Incorrect path to SHOJIRU"
    );

    require(
      _pathToWtlos[0] == address(_farmRewardToken) &&
        _pathToWtlos[_pathToWtlos.length - 1] == WTLOS,
      "ShojiVault: Incorrect path to WTLOS"
    );

    require(_buyBackRate <= buyBackRateUL);
    require(_platformFee <= platformFeeUL);

    AUTO_SHOJIRU = IShojiruVault(_autoShojiru);
    STAKED_TOKEN = IERC20(_stakedToken);
    STAKED_TOKEN_FARM = IFarm(_stakedTokenFarm);
    FARM_REWARD_TOKEN = IERC20(_farmRewardToken);
    FARM_PID = _farmPid;
    IS_CAKE_STAKING = _isCakeStaking;

    router = IPancakeRouter02(_router);
    WTLOS = router.WETH();
    pathToShojiru = _pathToShojiru;
    pathToWtlos = _pathToWtlos;

    buyBackRate = _buyBackRate;
    platformFee = _platformFee;

    transferOwnership(_owner);
    treasury = _treasury;
    keeper = _keeper;
    platform = _platform;
  }

  /**
   * @dev Throws if called by any account other than the keeper.
   */
  modifier onlyKeeper() {
    require(keeper == msg.sender, "ShojiVault: caller is not the keeper");
    _;
  }

  /**
   * @notice The earn function manages the harvesting & staking of the rewards
   * @dev You need to be the keeper to trigger it.
   * @dev Here is the workflow:
   * @dev 1. Harvest rewards
   * @dev 2. Collect fees
   * @dev 3. Convert rewards to $SHOJIRU
   * @dev 4. Stake to shojiru auto-compound vault
   * @dev Parameters are here to prevent any MEV attack or high slippage
   * @param _minFeeOutput Min output for fees
   * @param _minBurnOutput Min output for burn
   * @param _minShojiruOutput Min output for staked shojiru
   **/
  function earn(
    uint256 _minFeeOutput,
    uint256 _minBurnOutput,
    uint256 _minShojiruOutput
  ) external onlyKeeper {
    if (IS_CAKE_STAKING) {
      STAKED_TOKEN_FARM.leaveStaking(0);
    } else {
      STAKED_TOKEN_FARM.withdraw(FARM_PID, 0);
    }

    // How many tokens did we get?
    uint256 rewardTokenBalance = _rewardTokenBalance();

    // Collect platform and keeper fees
    if (platformFee > 0 || keeperFee > 0) {
      _swap(
        rewardTokenBalance.mul(platformFee.add(keeperFee)).div(denominator),
        _minFeeOutput,
        pathToWtlos,
        address(this)
      );
    }

    // We send the fees
    IERC20 _wtlos = IERC20(WTLOS);
    uint256 FeesCollected = IERC20(_wtlos).balanceOf(address(this));
    IERC20(_wtlos).transfer(
      platform,
      FeesCollected.mul(platformFee).div(platformFee.add(keeperFee))
    );
    IERC20(_wtlos).transfer(keeper, IERC20(_wtlos).balanceOf(address(this)));

    // Collect Burn fees
    if (buyBackRate > 0) {
      _swap(
        rewardTokenBalance.mul(buyBackRate).div(denominator),
        _minBurnOutput,
        pathToShojiru,
        BURN_ADDRESS
      );
    }

    // Convert remaining rewards to SHOJIRU
    _swap(
      _rewardTokenBalance(),
      _minShojiruOutput,
      pathToShojiru,
      address(this)
    );

    // Deposit SHOJIRU
    uint256 previousShares = totalAutoShojiruShares();
    uint256 shojiruBalance = _shojiruBalance();

    _approveTokenIfNeeded(SHOJIRU, shojiruBalance, address(AUTO_SHOJIRU));
    AUTO_SHOJIRU.deposit(shojiruBalance);

    // We update the data about rewards
    uint256 currentShares = totalAutoShojiruShares();
    accSharesPerStakedToken = accSharesPerStakedToken.add(
      currentShares.sub(previousShares).mul(1e18).div(totalStake())
    );
  }

  /**
   * @notice Allows the user to deposit tokens into the vault.
   * @dev Needs allowance from the user
   * @param _amount Amount of tokens deposited
    **/
  function deposit(uint256 _amount) external virtual nonReentrant {
    require(_amount > 0, "ShojiVault: amount must be greater than zero");

    UserInfo storage user = userInfo[msg.sender];

    STAKED_TOKEN.safeTransferFrom(address(msg.sender), address(this), _amount);

    _approveTokenIfNeeded(STAKED_TOKEN, _amount, address(STAKED_TOKEN_FARM));

    _deposit(_amount);

    // We update user data after having deposited
    user.autoShojiruShares = user.autoShojiruShares.add(
      user.stake.mul(accSharesPerStakedToken).div(1e18).sub(user.rewardDebt)
    );
    user.stake = user.stake.add(_amount);
    user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e18);
    user.lastDepositedTime = block.timestamp;

    emit Deposit(msg.sender, _amount);
  }

  function _deposit(uint256 _amount) internal virtual {
    if (IS_CAKE_STAKING) {
      STAKED_TOKEN_FARM.enterStaking(_amount);
    } else {
      STAKED_TOKEN_FARM.deposit(FARM_PID, _amount);
    }
  }

  /**
   * @notice Allows the user to withdraw his capital and his rewards
   * @dev Please make sure the user is aware about the early withdraw fees, if any
   * @param _amount The amount to withdraw
    **/
  function withdraw(uint256 _amount) external virtual nonReentrant {
    UserInfo storage user = userInfo[msg.sender];

    require(_amount > 0, "ShojiVault: amount must be greater than zero");
    require(
      user.stake >= _amount,
      "ShojiruVault: withdraw amount exceeds balance"
    );

    if (IS_CAKE_STAKING) {
      STAKED_TOKEN_FARM.leaveStaking(_amount);
    } else {
      STAKED_TOKEN_FARM.withdraw(FARM_PID, _amount);
    }

    uint256 currentAmount = _amount;

    // If the withdraw is too early, the penalty is paid to current depositors
    if (block.timestamp < user.lastDepositedTime.add(withdrawFeePeriod)) {
      uint256 currentWithdrawFee = currentAmount.mul(earlyWithdrawFee).div(
        denominator
      );

      STAKED_TOKEN.safeTransfer(treasury, currentWithdrawFee);

      currentAmount = currentAmount.sub(currentWithdrawFee);

      emit EarlyWithdraw(msg.sender, _amount, currentWithdrawFee);
    }

    // Update the user data
    user.autoShojiruShares = user.autoShojiruShares.add(
      user.stake.mul(accSharesPerStakedToken).div(1e18).sub(user.rewardDebt)
    );
    user.stake = user.stake.sub(_amount);
    user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e18);

    // Withdraw shojiru rewards if user leaves
    if (user.stake == 0 && user.autoShojiruShares > 0) {
      _claimRewards(user.autoShojiruShares, false);
    }

    STAKED_TOKEN.safeTransfer(msg.sender, currentAmount);

    emit Withdraw(msg.sender, currentAmount);
  }

  function claimRewards(uint256 _shares) external nonReentrant {
    _claimRewards(_shares, true);
  }

  function _claimRewards(uint256 _shares, bool _update) internal {
    UserInfo storage user = userInfo[msg.sender];

    if (_update) {
      user.autoShojiruShares = user.autoShojiruShares.add(
        user.stake.mul(accSharesPerStakedToken).div(1e18).sub(user.rewardDebt)
      );

      user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e18);
    }

    require(
      user.autoShojiruShares >= _shares,
      "ShojiVault: claim amount exceeds balance"
    );

    user.autoShojiruShares = user.autoShojiruShares.sub(_shares);

    uint256 shojiruBalanceBefore = _shojiruBalance();

    AUTO_SHOJIRU.withdraw(_shares);

    uint256 withdrawAmount = _shojiruBalance().sub(shojiruBalanceBefore);

    _safeSHOJIRUTransfer(msg.sender, withdrawAmount);

    emit ClaimRewards(msg.sender, _shares, withdrawAmount);
  }

  /**
   * @notice Helper to determine the optimal output parameter when swapping rewards
  **/
  function getExpectedOutputs()
    external
    view
    returns (
      uint256 feeOutput,
      uint256 burnOutput,
      uint256 shojiruOutput
    )
  {
    uint256 wtlosOutput = _getExpectedOutput(pathToWtlos);
    uint256 shojiruOutputWithoutFees = _getExpectedOutput(pathToShojiru);

    feeOutput = wtlosOutput.mul(platformFee.add(keeperFee)).div(denominator);
    burnOutput = shojiruOutputWithoutFees.mul(buyBackRate).div(denominator);

    shojiruOutput = shojiruOutputWithoutFees.sub(
      shojiruOutputWithoutFees
        .mul(platformFee.add(keeperFee))
        .div(denominator)
        .add(shojiruOutputWithoutFees.mul(keeperFee).div(denominator))
        .add(shojiruOutputWithoutFees.mul(buyBackRate).div(denominator))
    );
  }


  function _getExpectedOutput(address[] memory _path)
    internal
    view
    virtual
    returns (uint256)
  {
    uint256 pending;

    pending = STAKED_TOKEN_FARM.pendingCharm(FARM_PID, address(this));

    uint256 rewards = _rewardTokenBalance().add(pending);

    uint256[] memory amounts = router.getAmountsOut(rewards, _path);

    return amounts[amounts.length.sub(1)];
  }

  /**
   * @notice Helper to determine the amount deposited by the user
   * @return stake the amount of staked tokens (should be used for withdraw())
   * @return shojiru the amount of SHOJIRU staked that has been earned (should be displayed on the frontend)
   * @return autoShojiruShares shares of the user in the auto_shojiru vault
  **/
  function balanceOf(address _user)
    external
    view
    returns (
      uint256 stake,
      uint256 shojiru,
      uint256 autoShojiruShares
    )
  {
    UserInfo memory user = userInfo[_user];

    uint256 pendingShares = user
      .stake
      .mul(accSharesPerStakedToken)
      .div(1e18)
      .sub(user.rewardDebt);

    stake = user.stake;
    autoShojiruShares = user.autoShojiruShares.add(pendingShares);
    shojiru = autoShojiruShares.mul(AUTO_SHOJIRU.getPricePerFullShare()).div(
      1e18
    );
  }

  function _approveTokenIfNeeded(
    IERC20 _token,
    uint256 _amount,
    address _spender
  ) internal {
    if (_token.allowance(address(this), _spender) < _amount) {
      _token.safeIncreaseAllowance(_spender, _amount);
    }
  }

  function _rewardTokenBalance() internal view returns (uint256) {
    return FARM_REWARD_TOKEN.balanceOf(address(this));
  }

  function _shojiruBalance() private view returns (uint256) {
    return SHOJIRU.balanceOf(address(this));
  }

  /**
  @notice Total amount of tokens staked in the pool (not auto_shojiru)
  **/
  function totalStake() public view returns (uint256) {
    return STAKED_TOKEN_FARM.userInfo(FARM_PID, address(this));
  }

  /**
  @notice Total amount of shares staked in the auto_shojiru farm
  **/
  function totalAutoShojiruShares() public view returns (uint256) {
    (uint256 shares, , , ) = AUTO_SHOJIRU.userInfo(address(this));
    return shares;
  }

  // Safe SHOJIRU transfer function, just in case if rounding error causes pool to not have enough
  function _safeSHOJIRUTransfer(address _to, uint256 _amount) private {
    uint256 balance = _shojiruBalance();

    if (_amount > balance) {
      SHOJIRU.transfer(_to, balance);
    } else {
      SHOJIRU.transfer(_to, _amount);
    }
  }

  function _swap(
    uint256 _inputAmount,
    uint256 _minOutputAmount,
    address[] memory _path,
    address _to
  ) internal virtual {
    _approveTokenIfNeeded(FARM_REWARD_TOKEN, _inputAmount, address(router));

    router.swapExactTokensForTokens(
      _inputAmount,
      _minOutputAmount,
      _path,
      _to,
      block.timestamp
    );
  }

  ///////////////////////////////////
  /// SETTERS ///////////////////////
  ///////////////////////////////////

  /**
  @notice Allows the owner to change the path to Shogiru
  **/
  function setPathToShojiru(address[] memory _path) external onlyOwner {
    require(
      _path[0] == address(FARM_REWARD_TOKEN) &&
        _path[_path.length - 1] == address(SHOJIRU),
      "ShojiVault: Incorrect path to SHOJIRU"
    );

    address[] memory oldPath = pathToShojiru;

    pathToShojiru = _path;

    emit SetPathToShojiru(oldPath, pathToShojiru);
  }

  /**
  @notice Allows the owner to change the path to WTLOS
  **/
  function setPathToWtlos(address[] memory _path) external onlyOwner {
    require(
      _path[0] == address(FARM_REWARD_TOKEN) &&
        _path[_path.length - 1] == WTLOS,
      "ShojiVault: Incorrect path to WTLOS"
    );

    address[] memory oldPath = pathToWtlos;

    pathToWtlos = _path;

    emit SetPathToWtlos(oldPath, pathToWtlos);
  }

  /**
  @notice Allows the owner to set the treasury address
  **/
  function setTreasury(address _treasury) external onlyOwner {
    address oldTreasury = treasury;

    treasury = _treasury;

    emit SetTreasury(oldTreasury, treasury);
  }

  /**
  @notice Allows the owner to set the keeper address
  **/
  function setKeeper(address _keeper) external onlyOwner {
    address oldKeeper = keeper;

    keeper = _keeper;

    emit SetKeeper(oldKeeper, keeper);
  }

  /**
  @notice Allows the owner to set the keeper fee
  **/
  function setKeeperFee(uint256 _keeperFee) external onlyOwner {
    require(_keeperFee <= keeperFeeUL, "ShojiVault: Keeper fee too high");

    uint256 oldKeeperFee = keeperFee;

    keeperFee = _keeperFee;

    emit SetKeeperFee(oldKeeperFee, keeperFee);
  }

  /**
  @notice Allows the owner to set the platform address
  **/
  function setPlatform(address _platform) external onlyOwner {
    address oldPlatform = platform;

    platform = _platform;

    emit SetPlatform(oldPlatform, platform);
  }

  /**
  @notice Allows the owner to set the platform fee
  **/
  function setPlatformFee(uint256 _platformFee) external onlyOwner {
    require(_platformFee <= platformFeeUL, "ShojiVault: Platform fee too high");

    uint256 oldPlatformFee = platformFee;

    platformFee = _platformFee;

    emit SetPlatformFee(oldPlatformFee, platformFee);
  }

  /**
  @notice Allows the owner to set the buyback rate
  **/
  function setBuyBackRate(uint256 _buyBackRate) external onlyOwner {
    require(
      _buyBackRate <= buyBackRateUL,
      "ShojiVault: Buy back rate too high"
    );

    uint256 oldBuyBackRate = buyBackRate;

    buyBackRate = _buyBackRate;

    emit SetBuyBackRate(oldBuyBackRate, buyBackRate);
  }

  /**
  @notice Allows the owner to set the early withdraw fee
  **/
  function setEarlyWithdrawFee(uint256 _earlyWithdrawFee) external onlyOwner {
    require(
      _earlyWithdrawFee <= earlyWithdrawFeeUL,
      "ShojiVault: Early withdraw fee too high"
    );

    uint256 oldEarlyWithdrawFee = earlyWithdrawFee;

    earlyWithdrawFee = _earlyWithdrawFee;

    emit SetEarlyWithdrawFee(oldEarlyWithdrawFee, earlyWithdrawFee);
  }
}
