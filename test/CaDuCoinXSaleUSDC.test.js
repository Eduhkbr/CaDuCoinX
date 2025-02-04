const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("CaDuCoinXSaleUSDC", function () {
  let sale, token, usdc;
  let owner, buyer, treasury;

  beforeEach(async function () {
    [owner, buyer, treasury] = await ethers.getSigners();

    // Deploy do token CaDuCoinXToken (supondo que ele possua a função mint acessível via onlyOwner)
    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    token = await upgrades.deployProxy(CaDuCoinXToken, [owner.address, "CaDuCoinX", "CDX", owner.address], { initializer: "initialize" });
    await token.deployed();

    // Deploy do TestERC20 para simular o USDC com 6 decimais
    const TestERC20 = await ethers.getContractFactory("TestERC20");
    usdc = await TestERC20.deploy("USD Coin", "USDC", 6);
    await usdc.deployed();

    // Mint USDC para o buyer (por exemplo, 1.000.000 USDC)
    await usdc.mint(buyer.address, ethers.BigNumber.from("1000000000")); // 1e9, equivalente a 1,000,000 com 6 decimais

    // Deploy do contrato CaDuCoinXSaleUSDC via proxy upgradeable
    const CaDuCoinXSaleUSDC = await ethers.getContractFactory("CaDuCoinXSaleUSDC");
    sale = await upgrades.deployProxy(CaDuCoinXSaleUSDC, [token.address, usdc.address, treasury.address, owner.address], { initializer: "initialize" });
    await sale.deployed();
  });

  describe("Token Purchase", function () {
    it("should allow buyer to purchase tokens using USDC", async function () {
      // Escolhemos comprar 100 tokens.
      const tokenAmount = 100; // considerado em unidades inteiras conforme o contrato de Sale.
      const tokenPrice = await sale.tokenPrice(); // 8600 conforme inicialização.
      // Calcula o custo total = 100 * 8600 = 860000 (USDC com 6 decimais)
      const cost = tokenAmount * tokenPrice;

      // Verifica allowance do buyer para o contrato de Sale. Inicialmente, deve ser 0.
      expect(await usdc.allowance(buyer.address, sale.address)).to.equal(0);

      // O buyer aprova o contrato de sale para gastar USDC
      await usdc.connect(buyer).approve(sale.address, cost);

      // Registra o saldo do treasury antes
      const treasuryBalanceBefore = await usdc.balanceOf(treasury.address);

      // Realiza a compra dos tokens
      await expect(sale.connect(buyer).purchaseTokens(tokenAmount))
        .to.emit(sale, "TokensPurchased")
        .withArgs(buyer.address, tokenAmount, cost);

      // Verifica se o buyer recebeu os tokens minted
      const buyerTokenBalance = await token.balanceOf(buyer.address);
      expect(buyerTokenBalance).to.equal(tokenAmount);

      // Verifica se o treasury recebeu os USDC
      const treasuryBalanceAfter = await usdc.balanceOf(treasury.address);
      expect(treasuryBalanceAfter.sub(treasuryBalanceBefore)).to.equal(cost);
    });

    it("should revert purchase if allowance is insufficient", async function () {
      const tokenAmount = 50; // tentar comprar 50 tokens.
      const tokenPrice = await sale.tokenPrice();
      const cost = tokenAmount * tokenPrice;

      // Não aprova USDC e tenta comprar
      await expect(sale.connect(buyer).purchaseTokens(tokenAmount))
        .to.be.revertedWith("Allowance insuficiente para USDC");
    });

    it("should allow owner to update token price", async function () {
      const newPrice = 9000;
      await expect(sale.connect(owner).updateTokenPrice(newPrice))
        .to.emit(sale, "TokenPriceUpdated")
        .withArgs(newPrice);

      expect(await sale.tokenPrice()).to.equal(newPrice);
    });
  });
});