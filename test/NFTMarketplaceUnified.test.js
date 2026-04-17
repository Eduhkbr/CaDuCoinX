const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NFTMarketplaceUnified", function () {
  let marketplace, paymentToken, testNft;
  let owner, seller, buyer, feeCollector;
  const TOKEN_ID = 1;
  const ASSET_ID = 1;

  beforeEach(async function () {
    [owner, seller, buyer, feeCollector] = await ethers.getSigners();

    const TestERC20 = await ethers.getContractFactory("TestERC20");
    paymentToken = await TestERC20.deploy("Payment Token", "PTK");

    const TestNFT = await ethers.getContractFactory("TestNFT");
    testNft = await TestNFT.deploy("Test NFT", "TNFT");
    await testNft.mint(seller.address, TOKEN_ID);

    await paymentToken.mint(buyer.address, ethers.utils.parseEther("1000"));

    const NFTMarketplaceUnified = await ethers.getContractFactory("NFTMarketplaceUnified");
    marketplace = await upgrades.deployProxy(
      NFTMarketplaceUnified,
      [paymentToken.address, owner.address, feeCollector.address],
      { initializer: "initialize" }
    );
    await marketplace.deployed();
  });

  describe("Listing Assets", function () {
    it("should allow seller to list an NFT (escrow pattern)", async function () {
      const price = ethers.utils.parseEther("5");
      await testNft.connect(seller).approve(marketplace.address, TOKEN_ID);

      await expect(marketplace.connect(seller).listAsset(testNft.address, TOKEN_ID, price))
        .to.emit(marketplace, "AssetListed");

      // NFT should now be held by the marketplace (escrow)
      expect(await testNft.ownerOf(TOKEN_ID)).to.equal(marketplace.address);
    });

    it("should revert if marketplace is not approved", async function () {
      const price = ethers.utils.parseEther("5");
      await expect(marketplace.connect(seller).listAsset(testNft.address, TOKEN_ID, price))
        .to.be.revertedWith("Marketplace not approved to transfer NFT");
    });

    it("should revert if caller is not the NFT owner", async function () {
      const price = ethers.utils.parseEther("5");
      await expect(marketplace.connect(buyer).listAsset(testNft.address, TOKEN_ID, price))
        .to.be.revertedWith("Not the owner of the NFT");
    });
  });

  describe("Purchase Assets", function () {
    const price = ethers.utils.parseEther("5");

    beforeEach(async function () {
      await testNft.connect(seller).approve(marketplace.address, TOKEN_ID);
      await marketplace.connect(seller).listAsset(testNft.address, TOKEN_ID, price);
    });

    it("should allow buyer to purchase a listed NFT", async function () {
      await paymentToken.connect(buyer).approve(marketplace.address, price);
      await marketplace.connect(buyer).purchaseAsset(ASSET_ID);

      // Buyer now owns the NFT
      expect(await testNft.ownerOf(TOKEN_ID)).to.equal(buyer.address);
    });

    it("should correctly split payment between seller and fee collector", async function () {
      await paymentToken.connect(buyer).approve(marketplace.address, price);

      const sellerBalBefore = await paymentToken.balanceOf(seller.address);
      const feeBalBefore = await paymentToken.balanceOf(feeCollector.address);

      await marketplace.connect(buyer).purchaseAsset(ASSET_ID);

      const fee = price.mul(250).div(10000); // 2.5%
      const sellerAmount = price.sub(fee);

      expect(await paymentToken.balanceOf(seller.address)).to.equal(sellerBalBefore.add(sellerAmount));
      expect(await paymentToken.balanceOf(feeCollector.address)).to.equal(feeBalBefore.add(fee));
    });

    it("should revert purchase if buyer has insufficient allowance", async function () {
      await expect(marketplace.connect(buyer).purchaseAsset(ASSET_ID))
        .to.be.revertedWith("ERC20InsufficientAllowance");
    });

    it("should revert if seller tries to buy own asset", async function () {
      await paymentToken.mint(seller.address, price);
      await paymentToken.connect(seller).approve(marketplace.address, price);
      await expect(marketplace.connect(seller).purchaseAsset(ASSET_ID))
        .to.be.revertedWith("Cannot purchase own asset");
    });
  });

  describe("Delist Assets", function () {
    const price = ethers.utils.parseEther("5");

    beforeEach(async function () {
      await testNft.connect(seller).approve(marketplace.address, TOKEN_ID);
      await marketplace.connect(seller).listAsset(testNft.address, TOKEN_ID, price);
    });

    it("should allow seller to delist and return NFT", async function () {
      await expect(marketplace.connect(seller).delistAsset(ASSET_ID))
        .to.emit(marketplace, "AssetDelisted");

      // NFT returned to seller
      expect(await testNft.ownerOf(TOKEN_ID)).to.equal(seller.address);

      const asset = await marketplace.assets(ASSET_ID);
      expect(asset.isActive).to.be.false;
    });

    it("should revert delisting if caller is not the seller", async function () {
      await expect(marketplace.connect(buyer).delistAsset(ASSET_ID))
        .to.be.revertedWith("Not the asset seller");
    });
  });

  describe("Admin Functions", function () {
    const price = ethers.utils.parseEther("5");

    it("should allow owner to emergency delist", async function () {
      await testNft.connect(seller).approve(marketplace.address, TOKEN_ID);
      await marketplace.connect(seller).listAsset(testNft.address, TOKEN_ID, price);

      await marketplace.connect(owner).emergencyDelistAsset(ASSET_ID);

      expect(await testNft.ownerOf(TOKEN_ID)).to.equal(seller.address);
    });

    it("should allow owner to pause and unpause", async function () {
      await marketplace.connect(owner).pause();
      await testNft.connect(seller).approve(marketplace.address, TOKEN_ID);
      await expect(marketplace.connect(seller).listAsset(testNft.address, TOKEN_ID, price))
        .to.be.revertedWith("EnforcedPause");

      await marketplace.connect(owner).unpause();
      await marketplace.connect(seller).listAsset(testNft.address, TOKEN_ID, price);
    });
  });
});