const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("ItemsMarketplaceUnified", function () {
  let marketplace, paymentToken;
  let owner, seller, buyer, feeCollector;
  const ASSET_ID = 1;

  beforeEach(async function () {
    [owner, seller, buyer, feeCollector] = await ethers.getSigners();

    const TestERC20 = await ethers.getContractFactory("TestERC20");
    paymentToken = await TestERC20.deploy("Payment Token", "PTK");

    await paymentToken.mint(buyer.address, ethers.utils.parseEther("1000"));

    const ItemsMarketplaceUnified = await ethers.getContractFactory("ItemsMarketplaceUnified");
    marketplace = await upgrades.deployProxy(
      ItemsMarketplaceUnified,
      [paymentToken.address, owner.address, feeCollector.address],
      { initializer: "initialize" }
    );
    await marketplace.deployed();
  });

  describe("Listing Assets", function () {
    it("should allow seller to list an asset", async function () {
      const price = ethers.utils.parseEther("10");
      const assetName = "Sword of Valor";
      const category = "item";
      const quantity = 1;

      const tx = await marketplace.connect(seller).listAsset(assetName, price, category);
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt.blockNumber);

      await expect(tx)
        .to.emit(marketplace, "AssetListed")
        .withArgs(ASSET_ID, seller.address, assetName, price, category, quantity, block.timestamp);
    });
  });

  describe("Purchase Assets", function () {
    const price = ethers.utils.parseEther("10");

    beforeEach(async function () {
      const assetName = "Shield of Courage";
      const category = "item";
      await marketplace.connect(seller).listAsset(assetName, price, category);
    });

    it("should allow buyer to purchase a listed asset", async function () {
      const feePercentage = await marketplace.FEE_PERCENTAGE();
      const feeDenominator = await marketplace.FEE_DENOMINATOR();
      const fee = price.mul(feePercentage).div(feeDenominator);
      const totalPrice = price; // O comprador paga apenas o preço, o vendedor recebe menos a taxa
      const sellerAmount = price.sub(fee);

      await paymentToken.connect(buyer).approve(marketplace.address, totalPrice);

      const sellerBalanceBefore = await paymentToken.balanceOf(seller.address);
      await marketplace.connect(buyer).purchaseAsset(ASSET_ID);

      const sellerBalanceAfter = await paymentToken.balanceOf(seller.address);
      expect(sellerBalanceAfter.sub(sellerBalanceBefore)).to.equal(sellerAmount);
    });

    it("should revert purchase if buyer has insufficient allowance", async function () {
      await expect(marketplace.connect(buyer).purchaseAsset(ASSET_ID))
        .to.be.revertedWith("ERC20InsufficientAllowance");
    });
  });

  describe("Delist Assets", function () {
    beforeEach(async function () {
      const price = ethers.utils.parseEther("20");
      const assetName = "Magic Wand";
      const category = "item";
      await marketplace.connect(seller).listAsset(assetName, price, category);
    });

    it("should allow seller to delist their asset", async function () {
      const tx = await marketplace.connect(seller).delistAsset(ASSET_ID);
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt.blockNumber);

      await expect(tx)
        .to.emit(marketplace, "AssetDelisted")
        .withArgs(ASSET_ID, seller.address, block.timestamp);
    });

    it("should revert delisting if caller is not the seller", async function () {
      await expect(marketplace.connect(buyer).delistAsset(ASSET_ID))
        .to.be.revertedWith("Not the asset seller");
    });
  });
});