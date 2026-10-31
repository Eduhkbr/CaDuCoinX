const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployFixture } = require("./helpers/deploy");

describe("CaDuCoinXToken", function () {
    let owner, alice, bob, token, gameToken;

    beforeEach(async function () {
        ({ owner, alice, bob, token, gameToken } = await deployFixture());
    });

    it("initializes the proxy and assigns GameToken ownership to it", async function () {
        expect(await token.name()).to.equal("CaDuCoinX");
        expect(await token.symbol()).to.equal("CDX");
        expect(await token.owner()).to.equal(await owner.getAddress());
        expect(await gameToken.owner()).to.equal(await token.getAddress());
    });

    it("allows only the owner to mint and accounts for the supply cap", async function () {
        const amount = ethers.parseUnits("1000", 18);
        await token.mint(await alice.getAddress(), amount);
        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount);

        await expect(token.connect(alice).mint(await bob.getAddress(), 1))
            .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount")
            .withArgs(await alice.getAddress());

        await expect(token.mint(await owner.getAddress(), await token.MAX_SUPPLY()))
            .to.be.revertedWith("Exceeds available supply");
    });

    it("lets each holder burn only their own balance", async function () {
        const amount = ethers.parseUnits("10", 18);
        await token.mint(await alice.getAddress(), amount);
        await token.connect(alice).burn(amount);
        expect(await token.balanceOf(await alice.getAddress())).to.equal(0);

        await expect(token.connect(bob).burn(1))
            .to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
    });

    it("pauses mint and new activity while keeping ERC20 transfers available", async function () {
        const amount = ethers.parseUnits("10", 18);
        await token.mint(await alice.getAddress(), amount);
        await token.pause();

        await expect(token.mint(await bob.getAddress(), 1))
            .to.be.revertedWithCustomError(token, "EnforcedPause");
        await token.connect(alice).transfer(await bob.getAddress(), amount);
        expect(await token.balanceOf(await bob.getAddress())).to.equal(amount);

        await expect(token.connect(alice).pause())
            .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
        await token.unpause();
    });

    it("blocks direct initialization of the UUPS implementation", async function () {
        const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
        const implementation = await CaDuCoinXToken.deploy();
        await implementation.waitForDeployment();

        await expect(implementation.initialize(
            await owner.getAddress(),
            "CaDuCoinX",
            "CDX",
            await gameToken.getAddress()
        )).to.be.revertedWithCustomError(implementation, "InvalidInitialization");
    });

    it("validates UUPS upgrades and preserves proxy state", async function () {
        const amount = ethers.parseUnits("42", 18);
        await token.mint(await alice.getAddress(), amount);

        const V2 = await ethers.getContractFactory("CaDuCoinXTokenV2");
        const upgraded = await upgrades.upgradeProxy(await token.getAddress(), V2, { kind: "uups" });

        expect(await upgraded.version()).to.equal(2);
        expect(await upgraded.balanceOf(await alice.getAddress())).to.equal(amount);
        expect(await upgraded.owner()).to.equal(await owner.getAddress());
        expect(await upgraded.gameToken()).to.equal(await gameToken.getAddress());
    });

    it("routes authorized level changes through the proxy-owned GameToken", async function () {
        await token.levelUp(await alice.getAddress());
        const data = await token.getPlayerData(await alice.getAddress());
        expect(data.level).to.equal(1);
    });
});
