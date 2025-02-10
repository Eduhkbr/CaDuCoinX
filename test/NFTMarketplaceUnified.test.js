const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NFTMarketplaceUnified", function () {
  let marketplace, paymentToken;
  let owner, seller, buyer;

  beforeEach(async function () {
    [owner, seller, buyer] = await ethers.getSigners();

    // Deploy do TestERC20 para simular o token de pagamento (por exemplo, CaDuCoinXToken ou outro token)
    const TestERC20 = await ethers.getContractFactory("TestERC20");
    paymentToken = await TestERC20.deploy("Payment Token", "PTK");
    await paymentToken.deployed();

    // Mint tokens para o buyer (para que ele possa comprar NFTs)
    await paymentToken.mint(buyer.address, ethers.utils.parseEther("1000"));

    // Deploy do contrato NFTMarketplaceUnified via proxy upgradeable
    const NFTMarketplaceUnified = await ethers.getContractFactory("NFTMarketplaceUnified");
    // Inicializa com (paymentToken, owner)
    marketplace = await upgrades.deployProxy(
      NFTMarketplaceUnified,
      [paymentToken.address, owner.address],
      { initializer: "initialize" }
    );
    await marketplace.deployed();
  });

  describe("Listing Assets", function () {
    it("should allow seller to list an NFT", async function () {
      const price = ethers.utils.parseEther("5");
      const assetName = "Rare NFT Art";
      const category = "nft";

      // Seller lista o NFT usando a função listAsset (definida na interface)
      await expect(marketplace.connect(seller).listAsset(assetName, price, category))
        .to.emit(marketplace, "AssetListed")
        .withArgs(0, seller.address, assetName, price, category);

      // Verifica se o ativo foi listado corretamente
      const asset = await marketplace.assets(0);
      expect(asset.id).to.equal(0);
      expect(asset.name).to.equal(assetName);
      expect(asset.price).to.equal(price);
      expect(asset.seller).to.equal(seller.address);
      expect(asset.category).to.equal(category);
    });
  });

  describe("Purchase Assets", function () {
    beforeEach(async function () {
      // Seller lista um NFT
      const price = ethers.utils.parseEther("5");
      const assetName = "Digital Collectible NFT";
      const category = "nft";
      await marketplace.connect(seller).listAsset(assetName, price, category);
    });

    it("should allow buyer to purchase a listed NFT", async function () {
      const price = ethers.utils.parseEther("5");

      // Buyer precisa aprovar o marketplace para gastar os tokens
      await paymentToken.connect(buyer).approve(marketplace.address, price);

      // Salva o saldo do seller antes da compra
      const sellerBalanceBefore = await paymentToken.balanceOf(seller.address);

      // Buyer compra o NFT usando purchaseAsset
      await expect(marketplace.connect(buyer).purchaseAsset(0))
        .to.emit(marketplace, "AssetPurchased")
        .withArgs(0, buyer.address, price);

      // Verifica que o ativo foi removido (o registro é deletado, devolvendo valores nulos)
      const assetAfter = await marketplace.assets(0);
      expect(assetAfter.price).to.equal(0);

      // Verifica que o saldo do seller aumentou corretamente
      const sellerBalanceAfter = await paymentToken.balanceOf(seller.address);
      expect(sellerBalanceAfter.sub(sellerBalanceBefore)).to.equal(price);
    });

    it("should revert purchase if buyer has insufficient allowance", async function () {
      // Sem aprovação, a transferência deverá reverter com a mensagem padrão ERC20
      await expect(marketplace.connect(buyer).purchaseAsset(0))
        .to.be.revertedWith("ERC20InsufficientAllowance");
    });
  });

  describe("Delist Assets", function () {
    beforeEach(async function () {
      // Seller lista um NFT
      const price = ethers.utils.parseEther("5");
      const assetName = "Exclusive NFT";
      const category = "nft";
      await marketplace.connect(seller).listAsset(assetName, price, category);
    });

    it("should allow seller to delist their NFT", async function () {
      await expect(marketplace.connect(seller).delistAsset(0))
        .to.emit(marketplace, "AssetDelisted")
        .withArgs(0);

      // Verifica que o ativo foi removido (price deve estar zerado)
      const assetAfter = await marketplace.assets(0);
      expect(assetAfter.price).to.equal(0);
    });

    it("should revert delisting if caller is not the seller", async function () {
      await expect(marketplace.connect(buyer).delistAsset(0))
        .to.be.revertedWith("Caller is not the seller");
    });
  });
});