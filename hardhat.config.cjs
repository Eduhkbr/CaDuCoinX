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
        },/*
        optimism: {
            url: process.env.INFURA_SEPOLIA_URL,
            accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
            chainId: 11155420,
        },*/
    },
    etherscan: {
        apiKey: {
            optimism: process.env.ETHERSCAN_API_KEY
        },
        customChains: [
            {
                network: "optimism",
                chainId: 11155420,
                urls: {
                    apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
                    browserURL: "https://sepolia-optimism.etherscan.io/"                    
                }
            }
        ]
    },
    sourcify: {
        enabled: true
    }
};