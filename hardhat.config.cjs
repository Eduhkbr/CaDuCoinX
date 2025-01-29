require("@nomiclabs/hardhat-waffle");
require('@openzeppelin/hardhat-upgrades');
require("dotenv").config();

module.exports = {
    solidity: {
        version: "0.8.28",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    networks: {
        sepolia: {
            url: process.env.INFURA_SEPOLIA_URL,
            accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
            chainId: 11155111,
        },
    },
    verify: {
        etherscan: {
            apiKey: process.env.ETHERSCAN_API_KEY,
        },
    },
    sourcify: {
        enabled: true
    }
};