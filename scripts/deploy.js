const { ethers, upgrades } = require("hardhat");

const OPTIMISM_SEPOLIA_CHAIN_ID = 11155420n;

async function main() {
    const required = ["PRIVATE_KEY", "OPTIMISM_SEPOLIA_RPC_URL", "CDX_ADMIN_ADDRESS", "NAME_TOKEN", "SYMBOL"];
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

    const [deployer] = await ethers.getSigners();
    if (!deployer) {
        throw new Error("No deployer signer is configured");
    }
    console.log("Deploying from:", await deployer.getAddress());

    const GameToken = await ethers.getContractFactory("GameToken");
    const gameToken = await GameToken.deploy();
    await gameToken.waitForDeployment();

    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    const token = await upgrades.deployProxy(
        CaDuCoinXToken,
        [adminAddress, process.env.NAME_TOKEN, process.env.SYMBOL, await gameToken.getAddress()],
        { kind: "uups" }
    );
    await token.waitForDeployment();

    const tokenAddress = await token.getAddress();
    await (await gameToken.transferOwnership(tokenAddress)).wait();

    const gameOwner = ethers.getAddress(await gameToken.owner());
    if (gameOwner !== ethers.getAddress(tokenAddress)) {
        throw new Error("GameToken ownership transfer to the CDX proxy was not confirmed");
    }

    console.log("GameToken:", await gameToken.getAddress());
    console.log("CaDuCoinX implementation:", await upgrades.erc1967.getImplementationAddress(tokenAddress));
    console.log("CaDuCoinX proxy:", tokenAddress);
    console.log("CDX admin:", adminAddress);
    console.log("Chain ID:", network.chainId.toString());
}

main().catch((error) => {
    console.error("Deployment failed:", error.message);
    process.exitCode = 1;
});
