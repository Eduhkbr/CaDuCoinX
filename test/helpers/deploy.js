const { ethers, upgrades } = require("hardhat");

async function deployFixture() {
    const [owner, alice, bob, other] = await ethers.getSigners();
    const ownerAddress = await owner.getAddress();

    const GameToken = await ethers.getContractFactory("GameToken");
    const gameToken = await GameToken.deploy();
    await gameToken.waitForDeployment();

    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    const token = await upgrades.deployProxy(
        CaDuCoinXToken,
        [ownerAddress, "CaDuCoinX", "CDX", await gameToken.getAddress()],
        { kind: "uups" }
    );
    await token.waitForDeployment();
    await (await gameToken.transferOwnership(await token.getAddress())).wait();

    return { owner, alice, bob, other, token, gameToken };
}

module.exports = { deployFixture };
