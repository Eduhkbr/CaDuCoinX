const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

/**
 * Validates required environment variables
 * @throws {Error} If any required environment variable is missing
 */
function validateEnvironmentVariables() {
    const required = ['DEPLOYER_ADDRESS', 'NAME_TOKEN', 'SYMBOL'];
    const missing = required.filter(env => !process.env[env]);

    if (missing.length > 0) {
        throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }

    // Validate Ethereum address format
    if (!ethers.utils.isAddress(process.env.DEPLOYER_ADDRESS)) {
        throw new Error('DEPLOYER_ADDRESS is not a valid Ethereum address');
    }

    console.log("✅ Environment variables validated successfully");
}

/**
 * Deploys the CaDuCoinXToken logic contract
 * @returns {Promise<Contract>} The deployed logic contract
 */
async function deployLogicContract() {
    console.log("🚀 Deploying CaDuCoinXToken logic contract...");

    try {
        const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
        const logic = await CaDuCoinXToken.deploy();
        await logic.deployed();

        console.log("✅ CaDuCoinXToken logic contract deployed at:", logic.address);

        // Verify the deployment
        const code = await ethers.provider.getCode(logic.address);
        if (code === '0x') {
            throw new Error('Logic contract deployment failed - no code at address');
        }

        return logic;
    } catch (error) {
        console.error("❌ Failed to deploy logic contract:", error.message);
        throw error;
    }
}

/**
 * Deploys the CaDuCoinXTokenProxy contract
 * @param {string} logicAddress - Address of the logic contract
 * @param {string} initializeData - Encoded initialization data
 * @returns {Promise<Contract>} The deployed proxy contract
 */
async function deployProxyContract(logicAddress, initializeData) {
    console.log("🚀 Deploying CaDuCoinXTokenProxy...");

    try {
        // Validate inputs
        if (!ethers.utils.isAddress(logicAddress)) {
            throw new Error('Invalid logic contract address');
        }
        if (!initializeData || initializeData === '0x') {
            throw new Error('Invalid initialization data');
        }

        const CaDuCoinXTokenProxy = await ethers.getContractFactory("CaDuCoinXTokenProxy");
        const proxy = await CaDuCoinXTokenProxy.deploy(logicAddress, initializeData);
        await proxy.deployed();

        console.log("✅ CaDuCoinXTokenProxy deployed at:", proxy.address);

        // Verify the proxy is working
        const token = await ethers.getContractAt("CaDuCoinXToken", proxy.address);
        const name = await token.name();
        const symbol = await token.symbol();

        console.log("📋 Token verification:");
        console.log("   Name:", name);
        console.log("   Symbol:", symbol);
        console.log("   Admin:", await token.hasRole(await token.DEFAULT_ADMIN_ROLE(), process.env.DEPLOYER_ADDRESS));

        return proxy;
    } catch (error) {
        console.error("❌ Failed to deploy proxy contract:", error.message);
        throw error;
    }
}

/**
 * Deploys the NFTMarketplaceUnified contract
 * @param {string} tokenAddress - Address of the payment token
 * @returns {Promise<Contract>} The deployed NFT marketplace contract
 */
async function deployNFTMarketplaceUnifiedContract(tokenAddress) {
    console.log("🚀 Deploying NFTMarketplaceUnified...");

    try {
        if (!ethers.utils.isAddress(tokenAddress)) {
            throw new Error('Invalid token address for NFT marketplace');
        }

        const NFTMarketplaceUnified = await ethers.getContractFactory("NFTMarketplaceUnified");

        // Deploy with proper parameters: paymentToken, owner, feeCollector
        const feeCollector = process.env.FEE_COLLECTOR_ADDRESS || process.env.DEPLOYER_ADDRESS;

        const marketplace = await upgrades.deployProxy(
          NFTMarketplaceUnified,
          [tokenAddress, process.env.DEPLOYER_ADDRESS, feeCollector],
          {
              initializer: "initialize",
              kind: "transparent"
          }
        );
        await marketplace.deployed();

        console.log("✅ NFTMarketplaceUnified deployed at:", marketplace.address);

        // Verify deployment
        const paymentToken = await marketplace.paymentToken();
        const owner = await marketplace.owner();
        const collector = await marketplace.feeCollector();

        console.log("📋 NFT Marketplace verification:");
        console.log("   Payment Token:", paymentToken);
        console.log("   Owner:", owner);
        console.log("   Fee Collector:", collector);

        return marketplace;
    } catch (error) {
        console.error("❌ Failed to deploy NFT marketplace:", error.message);
        throw error;
    }
}

/**
 * Deploys the ItemsMarketplaceUnified contract
 * @param {string} tokenAddress - Address of the payment token
 * @returns {Promise<Contract>} The deployed items marketplace contract
 */
async function deployItemsMarketplaceUnifiedContract(tokenAddress) {
    console.log("🚀 Deploying ItemsMarketplaceUnified...");

    try {
        if (!ethers.utils.isAddress(tokenAddress)) {
            throw new Error('Invalid token address for items marketplace');
        }

        const ItemsMarketplaceUnified = await ethers.getContractFactory("ItemsMarketplaceUnified");

        // Deploy with proper parameters: paymentToken, owner, feeCollector
        const feeCollector = process.env.FEE_COLLECTOR_ADDRESS || process.env.DEPLOYER_ADDRESS;

        const marketplace = await upgrades.deployProxy(
          ItemsMarketplaceUnified,
          [tokenAddress, process.env.DEPLOYER_ADDRESS, feeCollector],
          {
              initializer: "initialize",
              kind: "transparent"
          }
        );
        await marketplace.deployed();

        console.log("✅ ItemsMarketplaceUnified deployed at:", marketplace.address);

        // Verify deployment
        const paymentToken = await marketplace.paymentToken();
        const owner = await marketplace.owner();
        const collector = await marketplace.feeCollector();

        console.log("📋 Items Marketplace verification:");
        console.log("   Payment Token:", paymentToken);
        console.log("   Owner:", owner);
        console.log("   Fee Collector:", collector);

        return marketplace;
    } catch (error) {
        console.error("❌ Failed to deploy items marketplace:", error.message);
        throw error;
    }
}

/**
 * Generates and saves deployment information
 * @param {Object} contracts - Object containing all deployed contracts
 */
async function saveDeploymentInfo(contracts) {
    const network = await ethers.provider.getNetwork();
    const [deployer] = await ethers.getSigners();

    const deploymentInfo = {
        network: {
            name: network.name,
            chainId: network.chainId
        },
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        blockNumber: await ethers.provider.getBlockNumber(),
        contracts: {
            logic: contracts.logic?.address,
            proxy: contracts.proxy?.address,
            nftMarketplace: contracts.nftMarketplace?.address || process.env.NFT_CONTRACT_ADDRESS,
            itemsMarketplace: contracts.itemsMarketplace?.address || process.env.ITEM_CONTRACT_ADDRESS
        },
        configuration: {
            tokenName: process.env.NAME_TOKEN,
            tokenSymbol: process.env.SYMBOL,
            feeCollector: process.env.FEE_COLLECTOR_ADDRESS || process.env.DEPLOYER_ADDRESS
        }
    };

    console.log("\n📊 DEPLOYMENT SUMMARY");
    console.log("========================");
    console.log(JSON.stringify(deploymentInfo, null, 2));

    return deploymentInfo;
}

/**
 * Main deployment function
 */
async function main() {
    console.log("🎯 Starting CaDuCoinX Deployment Process");
    console.log("==========================================");

    try {
        // Validate environment variables
        validateEnvironmentVariables();

        // Get deployer info
        const [deployer] = await ethers.getSigners();
        const balance = await deployer.getBalance();

        console.log("👤 Deployer:", deployer.address);
        console.log("💰 Balance:", ethers.utils.formatEther(balance), "ETH");

        if (balance.lt(ethers.utils.parseEther("0.1"))) {
            console.warn("⚠️  Warning: Low balance, deployment might fail");
        }

        const contracts = {};

        // Check if logic contract already exists
        if (!process.env.LOGIC_CONTRACT_ADDRESS) {
            console.log("\n🔄 Deploying new contracts...");

            // Deploy logic contract
            contracts.logic = await deployLogicContract();

            // Prepare initialization data
            console.log("📝 Preparing initialization data...");
            const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
            const initializeData = CaDuCoinXToken.interface.encodeFunctionData("initialize", [
                process.env.DEPLOYER_ADDRESS,
                process.env.NAME_TOKEN,
                process.env.SYMBOL
            ]);

            console.log("✅ Initialization data prepared");

            // Deploy proxy contract
            contracts.proxy = await deployProxyContract(contracts.logic.address, initializeData);

            // Deploy marketplaces if not already deployed
            if (!process.env.NFT_CONTRACT_ADDRESS || !process.env.ITEM_CONTRACT_ADDRESS) {
                console.log("\n🏪 Deploying marketplaces...");

                if (!process.env.NFT_CONTRACT_ADDRESS) {
                    contracts.nftMarketplace = await deployNFTMarketplaceUnifiedContract(contracts.proxy.address);
                }

                if (!process.env.ITEM_CONTRACT_ADDRESS) {
                    contracts.itemsMarketplace = await deployItemsMarketplaceUnifiedContract(contracts.proxy.address);
                }
            }

            console.log("\n🎉 All contracts deployed successfully!");

        } else {
            console.log("\n📋 Using existing contracts:");
            console.log("   Logic Address:", process.env.LOGIC_CONTRACT_ADDRESS);
            console.log("   Proxy Address:", process.env.PROXY_CONTRACT_ADDRESS);
            console.log("   NFT Marketplace:", process.env.NFT_CONTRACT_ADDRESS || "Not deployed");
            console.log("   Items Marketplace:", process.env.ITEM_CONTRACT_ADDRESS || "Not deployed");
        }

        // Save deployment information
        await saveDeploymentInfo(contracts);

        console.log("\n✅ Deployment completed successfully!");
        console.log("💡 Save these addresses to your .env file for future use");

    } catch (error) {
        console.error("\n❌ Deployment failed:", error.message);
        console.error("🔍 Full error:", error);
        throw error;
    }
}

// Execute deployment if this script is run directly
if (require.main === module) {
    main()
      .then(() => {
          console.log("\n🏁 Script executed successfully");
          process.exit(0);
      })
      .catch((error) => {
          console.error("\n💥 Script failed:", error.message);
          process.exit(1);
      });
}

module.exports = {
    main,
    deployLogicContract,
    deployProxyContract,
    deployNFTMarketplaceUnifiedContract,
    deployItemsMarketplaceUnifiedContract
};