const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("ItemsMarketplaceUnified", function () {
  let marketplace, paymentToken;
  let owner, seller, buyer;

  beforeEach(async function () {
    [owner, seller, buyer] = await ethers.getSigners();

    // Deploy do TestERC20 para simular o token de pagamento (ex.: CaDuCoinXToken ou token de pagamento dedicado)
    const TestERC20 = await ethers.getContractFactory("TestERC20");
    paymentToken = await TestERC20.deploy("Payment Token", "PTK", 18);
    await paymentToken.deployed();

    // Mint tokens para o buyer, que irá comprar ativos
    await paymentToken.mint(buyer.address, ethers.utils.parseEther("1000"));

    // Deploy do contrato ItemsMarketplaceUnified via proxy upgradeable
    const ItemsMarketplaceUnified = await ethers.getContractFactory("ItemsMarketplaceUnified");
    // Inicializa o marketplace com (paymentToken, owner)
    marketplace = await upgrades.deployProxy(
      ItemsMarketplaceUnified,
      [paymentToken.address, owner.address],
      { initializer: "initialize" }
    );
    await marketplace.deployed();
  });

  describe("Listing Assets", function () {
    it("should allow seller to list an asset", async function () {
      const price = ethers.utils.parseEther("10");
      const assetName = "Sword of Valor";
      const category = "item";
      
      // Seller lista o ativo usando a função listAsset
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
      // Seller lista um ativo para venda
      const price = ethers.utils.parseEther("10");
      const assetName = "Shield of Courage";
      const category = "item";
      await marketplace.connect(seller).listAsset(assetName, price, category);
    });

    it("should allow buyer to purchase a listed asset", async function () {
      const price = ethers.utils.parseEther("10");

      // Buyer deve aprovar o marketplace para gastar o preço do ativo
      await paymentToken.connect(buyer).approve(marketplace.address, price);

      // Salva o saldo do seller antes da compra
      const sellerBalanceBefore = await paymentToken.balanceOf(seller.address);

      // Buyer compra o ativo usando purchaseAsset
      await expect(marketplace.connect(buyer).purchaseAsset(0))
        .to.emit(marketplace, "AssetPurchased")
        .withArgs(0, buyer.address, price);

      // Verifica que o ativo foi removido (price deve ser zero pois a struct foi deletada)
      const assetAfter = await marketplace.assets(0);
      expect(assetAfter.price).to.equal(0);

      // Verifica se os tokens foram transferidos para o seller
      const sellerBalanceAfter = await paymentToken.balanceOf(seller.address);
      expect(sellerBalanceAfter.sub(sellerBalanceBefore)).to.equal(price);
    });

    it("should revert purchase if buyer has insufficient allowance", async function () {
      // Sem aprovação, a transferência deve reverter com a mensagem padrão do ERC20
      await expect(marketplace.connect(buyer).purchaseAsset(0))
        .to.be.revertedWith("ERC20InsufficientAllowance");
    });
  });

  describe("Delist Assets", function () {
    beforeEach(async function () {
      // Seller lista um ativo
      const price = ethers.utils.parseEther("20");
      const assetName = "Magic Wand";
      const category = "item";
      await marketplace.connect(seller).listAsset(assetName, price, category);
    });

    it("should allow seller to delist their asset", async function () {
      await expect(marketplace.connect(seller).delistAsset(0))
        .to.emit(marketplace, "AssetDelisted")
        .withArgs(0);
      
      // Verifica que o ativo foi removido (price deve ser zero após deleção)
      const assetAfter = await marketplace.assets(0);
      expect(assetAfter.price).to.equal(0);
    });

    it("should revert delisting if caller is not the seller", async function () {
      await expect(marketplace.connect(buyer).delistAsset(0))
        .to.be.revertedWith("Caller is not the seller");
    });
  });
});