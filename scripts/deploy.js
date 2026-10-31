const { ethers, upgrades } = require("hardhat");

const OPTIMISM_SEPOLIA_CHAIN_ID = 11155420n;

async function main() {
    const required = ["PRIVATE_KEY", "OPTIMISM_SEPOLIA_RPC_URL", "CDX_ADMIN_ADDRESS", "NAME_TOKEN", "SYMBOL", "UNISWAP_V3_FACTORY_ADDRESS"];
    const missing = required.filter((name) => !process.env[name]);
    if (missing.length > 0) {
        throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
    }

    const network = await ethers.provider.getNetwork();
    if (network.chainId !== OPTIMISM_SEPOLIA_CHAIN_ID) {
        throw new Error(`Refusing deployment: expected Optimism Sepolia (${OPTIMISM_SEPOLIA_CHAIN_ID}), got ${network.chainId}`);
    }

    const adminAddress = ethers.getAddress(process.env.CDX_ADMIN_ADDRESS);
    if (adminAddress === ethers.ZeroAddress) {
        throw new Error("CDX_ADMIN_ADDRESS must not be the zero address");
    }
    const feeCollectorAddress = ethers.getAddress(process.env.CDX_FEE_COLLECTOR_ADDRESS || adminAddress);
    if (feeCollectorAddress === ethers.ZeroAddress) {
        throw new Error("CDX_FEE_COLLECTOR_ADDRESS must not be the zero address");
    }
    const factoryAddress = ethers.getAddress(process.env.UNISWAP_V3_FACTORY_ADDRESS);
    if ((await ethers.provider.getCode(factoryAddress)) === "0x") {
        throw new Error("UNISWAP_V3_FACTORY_ADDRESS has no contract code on the selected network");
    }

    const [deployer] = await ethers.getSigners();
    if (!deployer) {
        throw new Error("No deployer signer is configured");
    }
    console.log("Deploying from:", await deployer.getAddress());

    const Oracle = await ethers.getContractFactory("UniswapV3TwapOracle");
    const oracle = await Oracle.deploy(factoryAddress);
    await oracle.waitForDeployment();

    const GameToken = await ethers.getContractFactory("GameToken");
    const gameToken = await GameToken.deploy();
    await gameToken.waitForDeployment();

    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    const token = await upgrades.deployProxy(
        CaDuCoinXToken,
        [adminAddress, process.env.NAME_TOKEN, process.env.SYMBOL, await gameToken.getAddress(), await oracle.getAddress()],
        { kind: "uups" }
    );
    await token.waitForDeployment();

    const tokenAddress = await token.getAddress();
    await (await gameToken.transferOwnership(tokenAddress)).wait();

    const gameOwner = ethers.getAddress(await gameToken.owner());
    if (gameOwner !== ethers.getAddress(tokenAddress)) {
        throw new Error("GameToken ownership transfer to the CDX proxy was not confirmed");
    }

    const NFTMarketplace = await ethers.getContractFactory("CaDuCoinXNFTMarketplace");
    const nftMarketplace = await upgrades.deployProxy(
        NFTMarketplace,
        [tokenAddress, adminAddress, feeCollectorAddress],
        { kind: "uups" }
    );
    await nftMarketplace.waitForDeployment();

    if (ethers.getAddress(await nftMarketplace.owner()) !== adminAddress) {
        throw new Error("NFT marketplace admin was not initialized correctly");
    }
    if (ethers.getAddress(await nftMarketplace.feeCollector()) !== feeCollectorAddress) {
        throw new Error("NFT marketplace fee collector was not initialized correctly");
    }
    if (ethers.getAddress(await nftMarketplace.paymentToken()) !== tokenAddress) {
        throw new Error("NFT marketplace payment token was not initialized correctly");
    }

    console.log("GameToken:", await gameToken.getAddress());
    console.log("Uniswap V3 TWAP oracle:", await oracle.getAddress());
    console.log("Buyback enabled: no (requires pool configuration, TWAP observations, and manual budget)");
    console.log("CaDuCoinX implementation:", await upgrades.erc1967.getImplementationAddress(tokenAddress));
    console.log("CaDuCoinX proxy:", tokenAddress);
    console.log("NFT marketplace implementation:", await upgrades.erc1967.getImplementationAddress(await nftMarketplace.getAddress()));
    console.log("NFT marketplace proxy:", await nftMarketplace.getAddress());
    console.log("CDX admin:", adminAddress);
    console.log("Marketplace fee collector:", feeCollectorAddress);
    console.log("Chain ID:", network.chainId.toString());
}

main().catch((error) => {
    console.error("Deployment failed:", error.message);
    process.exitCode = 1;
});
