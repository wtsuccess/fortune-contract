// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const _usdc = "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359"; // polygon USDC address
  const _usdce = "0x2791bca1f2de4661ed88a30c99a7a9449aa84174"; // polygon USDCE address
  const _vrfCoordinator = "0xec0Ed46f36576541C75739E915ADbCb3DE24bD77"; //polygon mainnet coordinator
  const Fortune = await hre.ethers.getContractFactory("Fortune");
  const fortune = await Fortune.deploy(_usdc, _usdce, _vrfCoordinator);

  await fortune.deployed();

  console.log(
    `deployed to ${fortune.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
