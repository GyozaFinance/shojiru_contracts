// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { getContractFactory } = require("@nomiclabs/hardhat-ethers/types");
const hre = require("hardhat");
const ethers = hre.ethers;

// Shojiru deployed to: 0x457b7b28f0D5FDaeFD2a4670a96A35237E3eeb85
// sjr_telos_lp deployed to: 0x8959f2F2F412dAD20F81CBd1C84cfb9A7b095c1d
// Shojiru Farm deployed to: 0xdA4D2F68366272baA146a401b8903f9c1B2967eA
// Shojiru strat deployed to: 0x0c551BaE4A7C700FebBb7e1B32ac55b6fA21fC8C
// AutoShojiru deployed to: 0x89efA3a473F78304e8385b07E848eb75030cd6aA
// staking_sjr_telos_lp deployed to: 0x8fE2fa6ECE2528a0F6e4D51b66F9FbE20810E79e
// Ethereum-Tlos vault deployed to: 0x716FAf38940edd7399BD873AfBC442dCE9206422
// Zappy-Tlos vault deployed to: 0xE714F8245976440f67d92BFC63c50692B6d2D5D0

// # Scanned farm :  0x3D2c6bCED5f50f5412234b87fF0B445aBA4d10e9
// # 9 pools available
// # ----------------------------------------------------
// # Pool:           0
// # LP token name   Zappy LP
// # LP address      0x774d427B2105849A0FBb6f49c432C087E3607F6F
// # alloc points    300
 
// # Token0:         0x9A271E3748F59222f5581BaE2540dAa5806b3F77      Zappy
// # Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
// # ----------------------------------------------------
// # Pool:           1
// # LP token name   Zappy LP
// # LP address      0xeA96c8d2FFA10FFeF65a87C957C27114051336F4
// # alloc points    90
 
// # Token0:         0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b      USD Coin
// # Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
// # ----------------------------------------------------
// # Pool:           2
// # LP token name   Zappy LP
// # LP address      0xA8A2ccbD5B130bd965Dc2C24fc8938AEa7493216
// # alloc points    44
 
// # Token0:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
// # Token1:         0xfA9343C3897324496A05fC75abeD6bAC29f8A40f      Ethereum
// # ----------------------------------------------------
// # Pool:           3
// # LP token name   Zappy LP
// # LP address      0x2C3dd9b87f5EcD49F6AE3566a5d61D8Ea6Dc21c2
// # alloc points    35
 
// # Token0:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
// # Token1:         0xf390830DF829cf22c53c8840554B98eafC5dCBc2      Wrapped BTC
// # ----------------------------------------------------
// # Pool:           4
// # LP token name   Zappy LP
// # LP address      0x06754b2a38782AA5c9B071Dc70A5C49457C7eBD1
// # alloc points    30
 
// # Token0:         0x332730a4F6E03D9C55829435f10360E13cfA41Ff      Matic
// # Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
// # ----------------------------------------------------
// # Pool:           5
// # LP token name   Zappy LP
// # LP address      0x8DFb20737aF995F78fAa5eB0349a7766EE3a543E
// # alloc points    30
 
// # Token0:         0x7C598c96D02398d89FbCb9d41Eab3DF0C16F227D      Avalanche
// # Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
// # ----------------------------------------------------
// # Pool:           6
// # LP token name   Zappy LP
// # LP address      0xa58615cB042e2ba96c8bef072aad256c15aC8372
// # alloc points    42
 
// # Token0:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
// # Token1:         0xeFAeeE334F0Fd1712f9a8cc375f427D9Cdd40d73      Tether USD
// # ----------------------------------------------------
// # Pool:           7
// # LP token name   Zappy LP
// # LP address      0x65980727179035C6A10dC5d79057B842e893627c
// # alloc points    30
 
// # Token0:         0x2C78f1b70Ccf63CDEe49F9233e9fAa99D43AA07e      Binance
// # Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS
// # ----------------------------------------------------
// # Pool:           8
// # LP token name   Zappy LP
// # LP address      0x62514Ad55D9fbb7eA66a915a1A1E11872F5FAA90
// # alloc points    30
 
// # Token0:         0xC1Be9a4D5D45BeeACAE296a7BD5fADBfc14602C4      Fantom
// # Token1:         0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E      Wrapped TLOS

async function main() {
  router = await ethers.getContractAt(
    "IPancakeRouter02",
    "0xB9239AF0697C8efb42cBA3568424b06753c6da71"
  );
  zappyFarm = await ethers.getContractAt(
    "IFarm",
    "0x3D2c6bCED5f50f5412234b87fF0B445aBA4d10e9"
  );
  zappyToken = await ethers.getContractAt(
    "IERC20",
    "0x9A271E3748F59222f5581BaE2540dAa5806b3F77"
  );

  wtlos = await ethers.getContractAt(
    "IERC20",
    "0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E"
  );
  shojiru = await ethers.getContractAt(
    "IERC20",
    "0x457b7b28f0D5FDaeFD2a4670a96A35237E3eeb85"
  );
  auto_sjr = await ethers.getContractAt(
    "AutoShojiru",
    "0x89efA3a473F78304e8385b07E848eb75030cd6aA"
  )

  const factoryAddress = await router.factory();
  const factory = await ethers.getContractAt("IPancakeFactory", factoryAddress);

  // We get the contract to deploy
  // const [owner, alice, bob] = await ethers.getSigners();
  const signers = await ethers.getSigners();
  const owner = signers[0];

  const ethereumTokenAddress = "0xfA9343C3897324496A05fC75abeD6bAC29f8A40f"
  const ShojiVault = await ethers.getContractFactory("ShojiVault", owner);
  const shojiVault = await ShojiVault.deploy(
    shojiru.address, // _Shojiru
    auto_sjr.address, // _autoShojiru
    "0x8DFb20737aF995F78fAa5eB0349a7766EE3a543E", // _stakedToken (lP)
    zappyFarm.address, // _StackedTokenFarm
    zappyToken.address, // _farmRewardToken
    5, // _farmPid
    false, // _isCakeStaking (single stacking, for PCS-like contracts)
    router.address, // router
    [zappyToken.address, wtlos.address, shojiru.address], // _pathToShojiru
    [zappyToken.address, wtlos.address], // _PathToWtlos
    owner.address, // _owner
    owner.address, // _treasury
    owner.address, // _keeper
    owner.address, // _platform
    30, // _buybackRate
    50 // PlatformFee
  );

  console.log("Avax-Tlos vault deployed to:", shojiVault.address);
  }

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// Ethereum-Tlos 0x716FAf38940edd7399BD873AfBC442dCE9206422 
// Bitcoin-Tlos  0x39cDf92031BC17dD1443065382F1CbA1d93aA405
// Matic-Tlos    0xe9DDAD4a953efe6738A824FC50484dC213ff4A2A
// Avax-Tlos     0x2a361d278Ac1ccb490151ECdc105B4A31466EfA1