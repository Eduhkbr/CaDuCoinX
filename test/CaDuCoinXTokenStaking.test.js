const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { deployFixture } = require("./helpers/deploy");

describe("CaDuCoinXToken staking", function () {
    let owner, alice, token;
    const year = 365 * 24 * 60 * 60;

    beforeEach(async function () {
        ({ owner, alice, token } = await deployFixture());
    });

    async function fundAndStake(amount, duration) {
        await token.mint(await alice.getAddress(), amount);
        await token.connect(alice).stake(amount, duration);
    }

    async function mature(duration) {
        await network.provider.send("evm_increaseTime", [duration + 1]);
        await network.provider.send("evm_mine");
    }

    it("calculates and reserves the 6% APR reward proportionally for all durations", async function () {
        const amount = ethers.parseUnits("1000", 18);
        const durations = [90 * 86400, 180 * 86400, 270 * 86400, year];
        let expectedTotal = 0n;

        for (const duration of durations) {
            await token.mint(await alice.getAddress(), amount);
            await token.connect(alice).stake(amount, duration);
            expectedTotal += amount * 600n * BigInt(duration) / (10_000n * BigInt(year));
        }

        expect(await token.reservedRewards()).to.equal(expectedTotal);
        const stakes = await token.getUserStakes(await alice.getAddress());
        expect(stakes.map((stake) => stake.rewardAmount)).to.deep.equal(
            durations.map((duration) => amount * 600n * BigInt(duration) / (10_000n * BigInt(year)))
        );
    });

    it("fixes the reward rate at stake time and pays a non-owner while paused", async function () {
        const amount = ethers.parseUnits("1000", 18);
        const duration = 90 * 86400;
        await fundAndStake(amount, duration);
        const expectedReward = amount * 600n * BigInt(duration) / (10_000n * BigInt(year));

        await token.updateInterestRate(1000);
        await token.pause();
        await mature(duration);
        await token.connect(alice).unstake(0);

        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount + expectedReward);
        expect(await token.reservedRewards()).to.equal(0);
        expect(await token.totalSupply()).to.equal(amount + expectedReward);
    });

    it("does not let owner mints consume rewards reserved for existing stakes", async function () {
        const amount = ethers.parseUnits("1000", 18);
        await fundAndStake(amount, year);
        const maxSupply = await token.MAX_SUPPLY();
        const reserved = await token.reservedRewards();
        const supply = await token.totalSupply();
        const remaining = maxSupply - supply - reserved;

        await token.mint(await owner.getAddress(), remaining);
        await expect(token.mint(await owner.getAddress(), 1))
            .to.be.revertedWith("Exceeds available supply");

        await mature(year);
        await token.connect(alice).unstake(0);
        expect(await token.totalSupply()).to.equal(maxSupply);
        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount + reserved);
    });

    it("rejects new stakes when the cap cannot reserve their rewards", async function () {
        const amount = ethers.parseUnits("1000", 18);
        await token.mint(await alice.getAddress(), amount);
        const maxSupply = await token.MAX_SUPPLY();
        const supply = await token.totalSupply();
        await token.mint(await owner.getAddress(), maxSupply - supply);

        await expect(token.connect(alice).stake(amount, year))
            .to.be.revertedWith("Insufficient reward capacity");
        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount);
        expect(await token.reservedRewards()).to.equal(0);
    });

    it("rejects invalid stakes and prevents withdrawal before maturity", async function () {
        const amount = ethers.parseUnits("100", 18);
        await token.mint(await alice.getAddress(), amount);

        await expect(token.connect(alice).stake(0, year)).to.be.revertedWith("Cannot stake 0");
        await expect(token.connect(alice).stake(amount, 1)).to.be.revertedWith("Invalid staking duration");

        const duration = 90 * 86400;
        await token.connect(alice).stake(amount, duration);
        await expect(token.connect(alice).unstake(0)).to.be.revertedWith("Staking period not completed");
        await expect(token.connect(alice).unstake(1)).to.be.revertedWith("Invalid stake index");
    });
});
