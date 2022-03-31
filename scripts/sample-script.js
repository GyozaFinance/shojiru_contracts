// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { getContractFactory } = require("@nomiclabs/hardhat-ethers/types");
const hre = require("hardhat");
const ethers = hre.ethers;

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  router = await ethers.getContractAt("IPancakeRouter02", '0xB9239AF0697C8efb42cBA3568424b06753c6da71')
  zappy = await ethers.getContractAt("IFarm", "0x3D2c6bCED5f50f5412234b87fF0B445aBA4d10e9")
  wtlos = await ethers.getContractAt("IERC20", "0xD102cE6A4dB07D247fcc28F366A623Df0938CA9E")

  // We get the contract to deploy
  const [owner, alice, bob] = await ethers.getSigners();
  const Shojiru = await ethers.getContractFactory("Shojiru", owner);
  const shojiru = await Shojiru.deploy();
  // console.log(owner.address)
  await shojiru.deployed();

  console.log("Shojiru deployed to:", shojiru.address);
  await shojiru.grantMinterRole(owner.address)
  await shojiru.mint(owner.address, new ethers.BigNumber.from("1000000", "ether"))
  await shojiru.approve(router.address, new ethers.BigNumber.from("1000000", "ether"))

  await router.addLiquidityETH(shojiru.address, 
      new ethers.BigNumber.from("1000", "ether"),
      0,
      0,
      owner.address,
      Math.floor(Date.now() / 1000) + 100,
      {"value": new ethers.BigNumber.from("100", "gwei")})


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
