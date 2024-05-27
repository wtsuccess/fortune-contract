// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const _usdc = "0x4379aE6e0b9b0d87a21a87E63E0a065a383a710b";
  const _vrfCoordinator = "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625";
  
  const Fortune = await hre.ethers.getContractFactory("Fortune");
  const fortune = await Fortune.deploy(_usdc, _vrfCoordinator);

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
