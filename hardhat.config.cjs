require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

require("dotenv").config();

const { subtask } = require("hardhat/config");
const { TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD } = require("hardhat/builtin-tasks/task-names");

subtask(TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD).setAction(async ({ solcVersion }, hre, runSuper) => {
    if (solcVersion === "0.8.28") {
        const solc = require("solc");
        return {
            compilerPath: require.resolve("solc/soljson.js"),
            isSolcJs: true,
            version: solcVersion,
            longVersion: solc.version(),
        };
    }
    if (solcVersion === "0.7.6") {
        const solc = require("solc-0.7.6");
        return {
            compilerPath: require.resolve("solc-0.7.6/soljson.js"),
            isSolcJs: true,
            version: solcVersion,
            longVersion: solc.version(),
        };
    }
    return runSuper();
});

module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.28",
                settings: {
                    evmVersion: "cancun",
                    optimizer: { enabled: true, runs: 200 },
                },
            },
            {
                version: "0.7.6",
                settings: {
                    optimizer: { enabled: true, runs: 200 },
                },
            },
        ],
    },
    networks: process.env.OPTIMISM_SEPOLIA_RPC_URL ? {
        optimismSepolia: {
            url: process.env.OPTIMISM_SEPOLIA_RPC_URL,
            accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
            chainId: 11155420,
        },
    } : {},
    sourcify: {
        enabled: true
    }
};
