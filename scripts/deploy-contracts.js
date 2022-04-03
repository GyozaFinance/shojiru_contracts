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
// Farm deployed to: 0xdA4D2F68366272baA146a401b8903f9c1B2967eA
// Staking_sjr deployed to: 0x0c551BaE4A7C700FebBb7e1B32ac55b6fA21fC8C
// Auto_sjr deployed to: 0x89efA3a473F78304e8385b07E848eb75030cd6aA
// shojiVault_tlos_zappy deployed to: 0xE714F8245976440f67d92BFC63c50692B6d2D5D0
// staking_sjr_telos_lp deployed to: 0x8fE2fa6ECE2528a0F6e4D51b66F9FbE20810E79e

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

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

  const factoryAddress = await router.factory();
  const factory = await ethers.getContractAt("IPancakeFactory", factoryAddress);

  // We get the contract to deploy
  // const [owner, alice, bob] = await ethers.getSigners();
  const signers = await ethers.getSigners();
  const owner = signers[0];
  // console.log(owner)
  const Shojiru = await ethers.getContractFactory("Shojiru", owner);
  const shojiru = await Shojiru.deploy();
  // console.log(owner.address)
  await shojiru.deployed();

  console.log("Shojiru deployed to:", shojiru.address);
  await shojiru.grantMinterRole(owner.address);
  await shojiru.mint(
    owner.address,
    new ethers.BigNumber.from("100000000000000000000000000")
  );
  await shojiru.approve(
    router.address,
    new ethers.BigNumber.from("100000000000000000000000000")
  );

  await factory.createPair(wtlos.address, shojiru.address);
  let sjr_telos_lp = await factory.getPair(wtlos.address, shojiru.address);
  console.log("sjr_telos_lp deployed to:", sjr_telos_lp);
  sjr_telos_lp = await ethers.getContractAt("IPancakePair", sjr_telos_lp);

  const Farm = await ethers.getContractFactory("ShojiruFarm", owner);
  const farm = await Farm.deploy(shojiru.address, 0);
  console.log("Farm deployed to:", farm.address);

  await shojiru.grantMinterRole(farm.address);

  const Staking_sjr = await ethers.getContractFactory("StratShojiru", owner);
  const staking_sjr = await Staking_sjr.deploy(
    shojiru.address,
    farm.address,
    owner.address
  );
  console.log("Staking_sjr deployed to:", staking_sjr.address);

  await farm.addPool(1000, shojiru.address, true, staking_sjr.address);

  const Auto_sjr = await ethers.getContractFactory("AutoShojiru", owner);
  const auto_sjr = await Auto_sjr.deploy(
    shojiru.address,
    farm.address,
    owner.address
  );
  console.log("Auto_sjr deployed to:", auto_sjr.address);

  const ShojiVault = await ethers.getContractFactory("ShojiVault", owner);
  const shojiVault_tlos_zappy = await ShojiVault.deploy(
    shojiru.address,
    auto_sjr.address,
    "0x774d427B2105849A0FBb6f49c432C087E3607F6F", // Zappy-tlos LP
    zappyFarm.address,
    zappyToken.address,
    0,
    false,
    router.address,
    [zappyToken.address, wtlos.address, shojiru.address],
    [zappyToken.address, wtlos.address],
    owner.address,
    owner.address,
    owner.address,
    owner.address,
    30,
    50
  );

  console.log("shojiVault_tlos_zappy deployed to:", shojiVault_tlos_zappy.address);

  // This fails when usign Telos+hardhat

  // await shojiru.approve(router, new ethers.BigNumber.from("10000", "ether"))
  // await router.addLiquidityETH(
  //   shojiru.address,
  //   new ethers.BigNumber.from("10000", "ether"),
  //   0,
  //   0,
  //   owner.address,
  //   Math.floor(Date.now() / 1000) + 100,
  //   { value: new ethers.BigNumber.from("1", "ether") }
  // );
  
  const staking_sjr_telos_lp = await Staking_sjr.deploy(
    sjr_telos_lp.address,
    farm.address,
    owner.address
  );

  console.log(
    "staking_sjr_telos_lp deployed to:",
    staking_sjr_telos_lp.address
  );

  await farm.addPool(300, sjr_telos_lp.address, true, staking_sjr_telos_lp.address);

  console.log("deployment complete!")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
