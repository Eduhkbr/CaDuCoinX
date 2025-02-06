const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("CaDuCoinXSaleUSDC", function () {
  let sale, token, usdc;
  let owner, buyer, treasury;
  let MINTER_ROLE;

  beforeEach(async function () {
    [owner, buyer, treasury] = await ethers.getSigners();

    // Deploy do token CaDuCoinXToken (com AccessControl implementado)
    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    token = await upgrades.deployProxy(
      CaDuCoinXToken,
      [owner.address, "CaDuCoinX", "CDX"],
      { initializer: "initialize" }
    );
    await token.deployed();

    // Obtém o hash do role MINTER_ROLE
    MINTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE"));

    // Deploy do TestERC20 para simular o USDC com 6 decimais
    const TestERC20 = await ethers.getContractFactory("TestERC20");
    usdc = await TestERC20.deploy("USD Coin", "USDC", 6);
    await usdc.deployed();

    // Mint USDC para o buyer (exemplo: 1.000.000 USDC, considerando 6 decimais)
    await usdc.mint(buyer.address, ethers.BigNumber.from("1000000000")); // 1e9 = 1,000,000 USDC

    // Deploy do contrato CaDuCoinXSaleUSDC via proxy upgradeable
    const CaDuCoinXSaleUSDC = await ethers.getContractFactory("CaDuCoinXSaleUSDC");
    sale = await upgrades.deployProxy(
      CaDuCoinXSaleUSDC,
      [token.address, usdc.address, treasury.address, owner.address],
      { initializer: "initialize" }
    );
    await sale.deployed();

    // Autoriza o contrato de sale com o papel MINTER_ROLE no token, para que ele possa chamar mint.
    await token.grantRole(MINTER_ROLE, sale.address);
  });

  describe("Token Purchase", function () {
    it("should allow buyer to purchase tokens using USDC", async function () {
      // Queremos comprar 100 tokens.
      const tokenAmount = 100; // unidades inteiras
      const tokenPrice = await sale.tokenPrice(); // deve ser 8600 conforme a inicialização
      const cost = tokenAmount * tokenPrice; // custo total em USDC

      // Verifica o allowance inicial do buyer para o contrato de sale (deve ser zero).
      expect(await usdc.allowance(buyer.address, sale.address)).to.equal(0);

      // O buyer aprova o contrato sale para gastar os USDC.
      await usdc.connect(buyer).approve(sale.address, cost);

      // Salva o saldo do treasury antes da compra.
      const treasuryBalanceBefore = await usdc.balanceOf(treasury.address);

      // Realiza a compra dos tokens.
      await expect(sale.connect(buyer).purchaseTokens(tokenAmount))
        .to.emit(sale, "TokensPurchased")
        .withArgs(buyer.address, tokenAmount, cost);

      // Verifica o balanço de tokens do buyer.
      const buyerTokenBalance = await token.balanceOf(buyer.address);
      expect(buyerTokenBalance).to.equal(tokenAmount);

      // Verifica se o treasury recebeu os USDC.
      const treasuryBalanceAfter = await usdc.balanceOf(treasury.address);
      expect(treasuryBalanceAfter.sub(treasuryBalanceBefore)).to.equal(cost);
    });

    it("should revert purchase if allowance is insufficient", async function () {
      const tokenAmount = 50;
      const tokenPrice = await sale.tokenPrice();
      const cost = tokenAmount * tokenPrice;
      
      // Sem aprovação, a compra deve reverter.
      await expect(sale.connect(buyer).purchaseTokens(tokenAmount))
        .to.be.revertedWith("Allowance insuficiente: cheque aprovacao e valor");
    });

    it("should allow owner to update token price", async function () {
      const newPrice = 9000;
      await expect(sale.connect(owner).updateTokenPrice(newPrice))
        .to.emit(sale, "TokenPriceUpdated")
        .withArgs(newPrice);
      expect(await sale.tokenPrice()).to.equal(newPrice);
    });

    
    it("should not allow others to update token price", async function () {
      const newPrice = 9000;
      await expect(sale.connect(buyer).updateTokenPrice(newPrice)).to.be.revertedWith("OwnableUnauthorizedAccount");
    });

    it("should correctly handle multiple purchases", async function () {
      const tokenPrice = await sale.tokenPrice();
      
      // Use ethers.utils.parseUnits para trabalhar com BigNumber
      const firstPurchaseAmount = ethers.utils.parseUnits("100", 18); // Assumindo que o token tem 18 decimais
      const secondPurchaseAmount = ethers.utils.parseUnits("50", 18); // Assumindo que o token tem 18 decimais
  
      await usdc.connect(buyer).mint(buyer.address, ethers.utils.parseUnits("10000000001000000000", 6));

      // Aprova o número total de USDC necessário
      const totalCost = tokenPrice.mul(firstPurchaseAmount).add(tokenPrice.mul(secondPurchaseAmount));
      await usdc.connect(buyer).approve(sale.address, totalCost);
  
      // Realiza a primeira compra
      await sale.connect(buyer).purchaseTokens(firstPurchaseAmount);
      expect(await token.balanceOf(buyer.address)).to.equal(firstPurchaseAmount);
  
      // Realiza a segunda compra
      await sale.connect(buyer).purchaseTokens(secondPurchaseAmount);
      expect(await token.balanceOf(buyer.address)).to.equal(firstPurchaseAmount.add(secondPurchaseAmount));
    });

    describe("Token Purchase Debugging Tests", function () {
      it("should show correct allowance and balance before purchase", async function () {
          const tokenAmount = 100;
          const tokenPrice = await sale.tokenPrice();
          const cost = tokenAmount * tokenPrice;
  
          // Tenta aprovar como teste
          await usdc.connect(buyer).approve(sale.address, cost);
          
          const allowance = await usdc.allowance(buyer.address, sale.address);
          const balance = await usdc.balanceOf(buyer.address);
  

          console.log(`Allowance before purchase: ${allowance.toString()}`);
          console.log(`USDC balance before purchase: ${balance.toString()}`);
          
          
          // Verifica a aprovação
          const updatedAllowance = await usdc.allowance(buyer.address, sale.address);
          expect(updatedAllowance).to.be.equal(cost);
      });
  });
  
    
  });
});
