const { ethers, upgrades } = require("hardhat");

async function deployFixture() {
    const [owner, alice, bob, other] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();

    const GameToken = await ethers.getContractFactory("GameToken");
    const gameToken = await GameToken.deploy();
    await gameToken.waitForDeployment();

    const Factory = await ethers.getContractFactory("MockUniswapV3Factory");
    const factory = await Factory.deploy();
    await factory.waitForDeployment();
    const WETH = await ethers.getContractFactory("MockWETH");
    const weth = await WETH.deploy();
    await weth.waitForDeployment();
    const Oracle = await ethers.getContractFactory("UniswapV3TwapOracle");
    const oracle = await Oracle.deploy(await factory.getAddress());
    await oracle.waitForDeployment();

    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    const token = await upgrades.deployProxy(
        CaDuCoinXToken,
        [ownerAddress, "CaDuCoinX", "CDX", await gameToken.getAddress(), await oracle.getAddress()],
        { kind: "uups" }
    );
    await token.waitForDeployment();
    await (await gameToken.transferOwnership(await token.getAddress())).wait();

    const NFTMarketplace = await ethers.getContractFactory("CaDuCoinXNFTMarketplace");
    const nftMarketplace = await upgrades.deployProxy(
        NFTMarketplace,
        [await token.getAddress(), ownerAddress, await other.getAddress()],
        { kind: "uups" }
    );
    await nftMarketplace.waitForDeployment();

    return { owner, alice, bob, other, token, gameToken, nftMarketplace, factory, weth, oracle };
}

async function mintBacked(token, owner, recipient, amount) {
    await token.connect(owner).mint(recipient, amount);
}

module.exports = { deployFixture, mintBacked };
