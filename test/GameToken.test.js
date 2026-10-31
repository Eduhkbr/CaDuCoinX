const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GameToken", function () {
    let owner, alice, gameToken;

    beforeEach(async function () {
        [owner, alice] = await ethers.getSigners();
        const GameToken = await ethers.getContractFactory("GameToken");
        gameToken = await GameToken.deploy();
        await gameToken.waitForDeployment();
    });

    it("assigns ownership in the constructor and increments player levels", async function () {
        expect(await gameToken.owner()).to.equal(await owner.getAddress());

        await gameToken.levelUp(await alice.getAddress());
        await gameToken.levelUp(await alice.getAddress());
        const playerData = await gameToken.getPlayerData(await alice.getAddress());
        expect(playerData.level).to.equal(2);
    });

    it("rejects level changes from non-owners and the zero address", async function () {
        await expect(gameToken.connect(alice).levelUp(await alice.getAddress()))
            .to.be.revertedWithCustomError(gameToken, "OwnableUnauthorizedAccount")
            .withArgs(await alice.getAddress());
        await expect(gameToken.levelUp(ethers.ZeroAddress)).to.be.revertedWith("Invalid player address");
    });
});
