// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const _usdc = "0x1671C11B783Ccd324f217A910d89891240880e20";
  const _usdce = "0x347917a0872d06FD0B86Cb00DEA4CD60D8b69d83";
  const _vrfCoordinator = "0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B";
  
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
