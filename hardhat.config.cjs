require("@nomicfoundation/hardhat-toolbox");
require("solidity-coverage");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

const {
  POLYGON_RPC_PROVIDER,
  PRIVATE_KEY,
  POLYGONSCAN_API_KEY,
  ETHERSCAN_API_KEY,
  PRIVATE_KEY_TESTNET,
} = process.env;

module.exports = {
  networks: {
    sepolia: {
      url: "https://ethereum-sepolia-rpc.publicnode.com",
      accounts: [PRIVATE_KEY_TESTNET],
    },
    polygon: {
      url: POLYGON_RPC_PROVIDER,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: POLYGONSCAN_API_KEY,
  },
  solidity: {
    gasReporter: {
      enabled: true,
    },
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
};
