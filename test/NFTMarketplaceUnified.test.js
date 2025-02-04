const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NFTMarketplaceUnified", function () {
  let marketplace, paymentToken, nft;
  let owner, seller, buyer;

  beforeEach(async function () {
    [owner, seller, buyer] = await ethers.getSigners();

    // Deploy TestERC20 para servir de token de pagamento.
    const TestERC20 = await ethers.getContractFactory("TestERC20");
    paymentToken = await TestERC20.deploy("Test Payment Token", "TPT", 6);
    await paymentToken.deployed();

    // Mint tokens para o buyer (ex: 1000 tokens com 18 decimais).
    await paymentToken.mint(buyer.address, ethers.utils.parseEther("1000"));

    // Deploy TestNFT para simular um contrato ERC721.
    const TestNFT = await ethers.getContractFactory("TestNFT");
    nft = await TestNFT.deploy("Test NFT", "TNFT");
    await nft.deployed();

    // Deploy do contrato NFTMarketplaceUnified via proxy upgradeable.
    const NFTMarketplaceUnified = await ethers.getContractFactory("NFTMarketplaceUnified");
    // O método initialize recebe: (IERC20 _paymentToken, address _owner)
    marketplace = await upgrades.deployProxy(NFTMarketplaceUnified, [paymentToken.address, owner.address], { initializer: "initialize" });
    await marketplace.deployed();
  });

  describe("Listing NFT", function () {
    it("deve permitir que o vendedor liste um NFT", async function () {
      // O vendedor mintará um NFT com tokenId 1.
      await nft.connect(seller).mint(seller.address, 1);
      // Aprova o marketplace para operar o NFT.
      await nft.connect(seller).approve(marketplace.address, 1);

      const price = ethers.utils.parseEther("100");
      await expect(marketplace.connect(seller).listNFT(nft.address, 1, price))
        .to.emit(marketplace, "NFTListed")
        .withArgs(0, seller.address, nft.address, 1, price);

      const sale = await marketplace.sales(0);
      expect(sale.seller).to.equal(seller.address);
      expect(sale.nftContract).to.equal(nft.address);
      expect(sale.tokenId).to.equal(1);
      expect(sale.price).to.equal(price);
    });
  });

  describe("Purchase NFT", function () {
    it("deve permitir que o comprador adquira um NFT listado", async function () {
      // O vendedor mintará e aprovará o NFT.
      await nft.connect(seller).mint(seller.address, 1);
      await nft.connect(seller).approve(marketplace.address, 1);
      const price = ethers.utils.parseEther("100");
      await marketplace.connect(seller).listNFT(nft.address, 1, price);
      
      // O buyer precisa aprovar o marketplace para gastar os tokens de pagamento.
      await paymentToken.connect(buyer).approve(marketplace.address, price);

      await expect(marketplace.connect(buyer).purchaseNFT(0))
        .to.emit(marketplace, "NFTPurchased")
        .withArgs(0, buyer.address, price);

      // Verifica que o NFT foi transferido para o buyer.
      expect(await nft.ownerOf(1)).to.equal(buyer.address);
    });
  });

  describe("Delist NFT", function () {
    it("deve permitir que o vendedor remova a listagem do seu NFT", async function () {
      // O vendedor mintará e aprovará o NFT.
      await nft.connect(seller).mint(seller.address, 1);
      await nft.connect(seller).approve(marketplace.address, 1);
      const price = ethers.utils.parseEther("100");
      await marketplace.connect(seller).listNFT(nft.address, 1, price);

      // Confirma que o sale foi criado.
      let sale = await marketplace.sales(0);
      expect(sale.price).to.equal(price);

      // O vendedor delista o NFT.
      await expect(marketplace.connect(seller).delistNFT(0))
          .to.emit(marketplace, "NFTDelisted")
          .withArgs(0);

      // Após a remoção, o preço da listagem deve ser zerado.
      sale = await marketplace.sales(0);
      expect(sale.price).to.equal(0);
    });
  });
});