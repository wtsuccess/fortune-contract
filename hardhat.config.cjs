require("@nomicfoundation/hardhat-toolbox");
require('solidity-coverage');
require('@openzeppelin/hardhat-upgrades');
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

const { POLYGON_RPC_PROVIDER, PRIVATE_KEY, POLYGONSCAN_API_KEY } = process.env;

module.exports = {
  networks: {
    // sepolia: {
    //   url: "https://rpc.sepolia.org",
    //   accounts: [secrets.account[0]]
    // },
    polygon: {
      url: POLYGON_RPC_PROVIDER,
      accounts: [PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: POLYGONSCAN_API_KEY,
  },
  solidity: {
    gasReporter: {
      enabled: true
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
    ]
  },
};
