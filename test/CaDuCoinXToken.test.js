const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { deployFixture, mintBacked } = require("./helpers/deploy");

async function configurePool(fixture, { tick = 0, liquidity = 1_000_000, history = 1800 } = {}) {
    const { token, weth, factory } = fixture;
    const tokenAddress = await token.getAddress();
    const wethAddress = await weth.getAddress();
    const [token0, token1] = BigInt(tokenAddress) < BigInt(wethAddress)
        ? [tokenAddress, wethAddress] : [wethAddress, tokenAddress];
    const Pool = await ethers.getContractFactory("MockUniswapV3Pool");
    const pool = await Pool.deploy(await factory.getAddress(), token0, token1, 3000);
    await pool.waitForDeployment();
    await pool.setOracle(tick, liquidity, history);
    await factory.setPool(token0, token1, 3000, await pool.getAddress());
    await token.configureBuybackPool(await pool.getAddress(), wethAddress, 100);
    return pool;
}

describe("CaDuCoinXToken", function () {
    let owner, alice, bob, token, gameToken, fixture;

    beforeEach(async function () {
        fixture = await deployFixture();
        ({ owner, alice, bob, token, gameToken } = fixture);
    });

    it("initializes the proxy and assigns GameToken ownership to it", async function () {
        expect(await token.name()).to.equal("CaDuCoinX");
        expect(await token.symbol()).to.equal("CDX");
        expect(await token.owner()).to.equal(await owner.getAddress());
        expect(await gameToken.owner()).to.equal(await token.getAddress());
        expect(await token.buybackActive()).to.equal(false);
    });

    it("allows owner mint without ETH collateral and accounts for supply cap", async function () {
        const amount = ethers.parseUnits("1000", 18);
        await mintBacked(token, owner, await alice.getAddress(), amount);
        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount);
        await expect(token.connect(alice).mint(await bob.getAddress(), 1))
            .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount").withArgs(await alice.getAddress());
        await expect(token.mint(await owner.getAddress(), await token.MAX_SUPPLY()))
            .to.be.revertedWith("Exceeds available supply");
    });

    it("lets each holder burn only their own balance", async function () {
        const amount = ethers.parseUnits("10", 18);
        await mintBacked(token, owner, await alice.getAddress(), amount);
        await token.connect(alice).burn(amount);
        expect(await token.balanceOf(await alice.getAddress())).to.equal(0);
        await expect(token.connect(bob).burn(1)).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
    });

    it("pauses mint and new activity while keeping ERC20 transfers available", async function () {
        const amount = ethers.parseUnits("10", 18);
        await mintBacked(token, owner, await alice.getAddress(), amount);
        await token.pause();
        await expect(token.mint(await bob.getAddress(), 1)).to.be.revertedWithCustomError(token, "EnforcedPause");
        await token.connect(alice).transfer(await bob.getAddress(), amount);
        expect(await token.balanceOf(await bob.getAddress())).to.equal(amount);
        await expect(token.connect(alice).pause()).to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
        await token.unpause();
    });

    it("blocks direct initialization of the UUPS implementation", async function () {
        const implementation = await (await ethers.getContractFactory("CaDuCoinXToken")).deploy();
        await implementation.waitForDeployment();
        await expect(implementation.initialize(await owner.getAddress(), "CaDuCoinX", "CDX", await gameToken.getAddress(), await fixture.oracle.getAddress()))
            .to.be.revertedWithCustomError(implementation, "InvalidInitialization");
    });

    it("validates UUPS upgrades and preserves staking and buyback state", async function () {
        const amount = ethers.parseUnits("42", 18);
        const duration = await token.THREE_MONTHS();
        await mintBacked(token, owner, await alice.getAddress(), amount);
        await token.connect(alice).stake(amount, duration);
        await configurePool(fixture);
        await token.depositEth({ value: ethers.parseEther("1") });
        await token.allocateBuybackBudget(ethers.parseEther("0.5"));
        const V2 = await ethers.getContractFactory("CaDuCoinXTokenV2");
        const upgraded = await upgrades.upgradeProxy(await token.getAddress(), V2, { kind: "uups" });
        expect(await upgraded.version()).to.equal(2);
        expect(await upgraded.owner()).to.equal(await owner.getAddress());
        expect(await upgraded.gameToken()).to.equal(await gameToken.getAddress());
        expect(await upgraded.MAX_SUPPLY()).to.equal(ethers.parseUnits("1000000000", 18));
        expect(await upgraded.reservedRewards()).to.be.gt(0);
        expect(await upgraded.buybackBudget()).to.equal(ethers.parseEther("0.5"));
        expect(await upgraded.buybackPool()).to.not.equal(ethers.ZeroAddress);
    });

    it("routes authorized level changes through the proxy-owned GameToken", async function () {
        await token.levelUp(await alice.getAddress());
        expect((await token.getPlayerData(await alice.getAddress())).level).to.equal(1);
    });

    it("sells tokens at 98% of the 30-minute TWAP and observes caller slippage", async function () {
        await configurePool(fixture);
        const amount = ethers.parseUnits("1", 18);
        await token.connect(alice).purchaseTokens({ value: await token.salePrice() });
        await token.depositEth({ value: ethers.parseEther("2") });
        await token.allocateBuybackBudget(ethers.parseEther("2"));
        await token.setBuybackActive(true);
        await expect(token.deallocateBuybackBudget(1)).to.be.revertedWith("Disable buybacks first");
        const expected = ethers.parseEther("0.98");
        await expect(token.connect(alice).sellTokens(amount, expected + 1n)).to.be.revertedWith("Below minimum ETH output");
        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount);
        const before = await ethers.provider.getBalance(await alice.getAddress());
        const tx = await token.connect(alice).sellTokens(amount, expected);
        const receipt = await tx.wait();
        const gas = receipt.gasUsed * receipt.gasPrice;
        expect(await ethers.provider.getBalance(await alice.getAddress()) + gas - before).to.equal(expected);
        expect(await token.balanceOf(await alice.getAddress())).to.equal(0);
        expect(await token.buybackBudget()).to.equal(ethers.parseEther("1.02"));
    });

    it("fails closed without a configured pool, valid history, or enough liquidity", async function () {
        await expect(token.setBuybackActive(true)).to.be.revertedWith("Buyback pool not configured");
        const pool = await configurePool(fixture, { history: 1799 });
        await expect(token.setBuybackActive(true)).to.be.revertedWith("Insufficient history");
        await pool.setOracle(0, 99, 1800);
        await expect(token.setBuybackActive(true)).to.be.revertedWith("Insufficient TWAP liquidity");
        await pool.setOracle(0, 1_000, 1800);
        await pool.setCurrentLiquidity(0);
        await expect(token.setBuybackActive(true)).to.be.revertedWith("Insufficient current liquidity");
        await pool.setCurrentLiquidity(1_000);
        await token.setBuybackActive(true);
        const amount = ethers.parseUnits("1", 18);
        await token.mint(await alice.getAddress(), amount);
        await token.depositEth({ value: ethers.parseEther("1") });
        await token.allocateBuybackBudget(ethers.parseEther("1"));
        await pool.setCurrentLiquidity(0);
        await expect(token.connect(alice).sellTokens(amount, 0)).to.be.revertedWith("Insufficient current liquidity");
        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount);
    });

    it("rejects a pool that does not represent the configured CDX/WETH pair", async function () {
        const Pool = await ethers.getContractFactory("MockUniswapV3Pool");
        const wrongPool = await Pool.deploy(await fixture.factory.getAddress(), await gameToken.getAddress(), await fixture.weth.getAddress(), 3000);
        await wrongPool.waitForDeployment();
        await expect(token.configureBuybackPool(await wrongPool.getAddress(), await fixture.weth.getAddress(), 100))
            .to.be.revertedWith("Pool token pair mismatch");
    });

    it("requires manual budget allocation and prevents treasury withdrawal of allocated ETH", async function () {
        await configurePool(fixture);
        await expect(token.allocateBuybackBudget(1)).to.be.revertedWith("Insufficient unallocated ETH");
        await token.depositEth({ value: 1000 });
        await token.allocateBuybackBudget(1000);
        expect(await token.unallocatedEth()).to.equal(0);
        await expect(token.withdrawUnallocatedEth(1)).to.be.revertedWith("Cannot withdraw allocated ETH");
        await expect(token.deallocateBuybackBudget(1001)).to.be.revertedWith("Amount exceeds buyback budget");
        await token.deallocateBuybackBudget(1000);
        expect(await token.buybackBudget()).to.equal(0);
        await token.withdrawUnallocatedEth(1000);
        expect(await token.unallocatedEth()).to.equal(0);
    });

    it("does not accept item purchases before item delivery and settlement exist", async function () {
        const amount = ethers.parseUnits("10", 18);
        await token.mint(await alice.getAddress(), amount);
        await token.addItem("Sword", ethers.parseUnits("5", 18));
        await expect(token.connect(alice).purchaseItem(0)).to.be.revertedWith("Item delivery not implemented");
        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount);
        expect(await token.balanceOf(await token.getAddress())).to.equal(0);
    });

    it("does not tie primary sale price to TWAP buyback quote", async function () {
        await configurePool(fixture);
        const before = await token.calculateEthForTokens(ethers.parseUnits("1", 18));
        await token.updateSalePrice(ethers.parseEther("0.01"));
        expect(await token.calculateEthForTokens(ethers.parseUnits("1", 18))).to.equal(before);
    });

    it("reverts the burn and budget decrement when the seller rejects ETH", async function () {
        await configurePool(fixture);
        const amount = ethers.parseUnits("1", 18);
        const Seller = await ethers.getContractFactory("RejectingBuybackSeller");
        const seller = await Seller.deploy();
        await seller.waitForDeployment();
        await token.mint(await seller.getAddress(), amount);
        await token.depositEth({ value: ethers.parseEther("1") });
        await token.allocateBuybackBudget(ethers.parseEther("1"));
        await token.setBuybackActive(true);
        const balanceBefore = await token.balanceOf(await seller.getAddress());
        const budgetBefore = await token.buybackBudget();
        await expect(seller.sell(await token.getAddress(), amount, 0)).to.be.revertedWith("ETH transfer failed");
        expect(await token.balanceOf(await seller.getAddress())).to.equal(balanceBefore);
        expect(await token.buybackBudget()).to.equal(budgetBefore);
    });

    it("cannot buy back more than the manually allocated budget", async function () {
        await configurePool(fixture);
        const amount = ethers.parseUnits("1", 18);
        await token.connect(alice).purchaseTokens({ value: await token.salePrice() });
        await token.depositEth({ value: ethers.parseEther("2") });
        await token.allocateBuybackBudget(ethers.parseEther("0.97"));
        await token.setBuybackActive(true);
        await expect(token.connect(alice).sellTokens(amount, 0)).to.be.revertedWith("Insufficient buyback budget");
        expect(await token.balanceOf(await alice.getAddress())).to.equal(amount);
    });

    it("allows owner to stop and resume primary sales", async function () {
        await token.setSaleActive(false);
        await expect(token.connect(alice).purchaseTokens({ value: await token.salePrice() })).to.be.revertedWith("Token sale is not active");
        await token.setSaleActive(true);
        await token.connect(alice).purchaseTokens({ value: await token.salePrice() });
        expect(await token.balanceOf(await alice.getAddress())).to.equal(ethers.parseUnits("1", 18));
    });

    it("blocks sales and buybacks while paused while keeping transfers available", async function () {
        await configurePool(fixture);
        await token.connect(alice).purchaseTokens({ value: await token.salePrice() });
        await token.depositEth({ value: ethers.parseEther("1") });
        await token.allocateBuybackBudget(ethers.parseEther("1"));
        await token.setBuybackActive(true);
        await token.pause();
        await expect(token.connect(alice).purchaseTokens({ value: await token.salePrice() })).to.be.revertedWithCustomError(token, "EnforcedPause");
        await expect(token.connect(alice).sellTokens(ethers.parseUnits("1", 18), 0)).to.be.revertedWithCustomError(token, "EnforcedPause");
        await token.connect(alice).transfer(await bob.getAddress(), ethers.parseUnits("1", 18));
        await token.unpause();
    });
});
