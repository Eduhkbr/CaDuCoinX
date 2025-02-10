// SPDX-License-Identifier: MIT

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CaDuCoinXToken", function () {
    let owner, addr1, token, proxy;
    let salePriceInitial;
    // Atualizado: o SELL_PRICE esperado é 98% do salePrice inicial (3300000000000 wei)
    const SELL_PRICE = ethers.BigNumber.from("3234000000000"); // 0.000003234 ETH

    beforeEach(async function () {
        // Obter contas
        [owner, addr1] = await ethers.getSigners();

        // Deploy do contrato lógico
        const TokenFactory = await ethers.getContractFactory("CaDuCoinXToken");
        token = await TokenFactory.deploy();
        await token.deployed();

        // Inicializar dados para o proxy
        const initializeData = token.interface.encodeFunctionData("initialize", [
            owner.address,
            "CaDuCoinX",
            "CDX"
        ]);

        // Deploy do proxy (supondo que o proxy esteja implementado corretamente)
        const ProxyFactory = await ethers.getContractFactory("CaDuCoinXTokenProxy");
        proxy = await ProxyFactory.deploy(token.address, initializeData);
        await proxy.deployed();

        // Conectar o contrato lógico ao proxy
        token = TokenFactory.attach(proxy.address);
        
        // Obter o salePrice inicial (deve ser 3300000000000 wei conforme o contrato)
        salePriceInitial = await token.salePrice();
    });

    it("Deve inicializar corretamente o contrato", async function () {
        expect(await token.name()).to.equal("CaDuCoinX");
        expect(await token.symbol()).to.equal("CDX");
        expect(await token.owner()).to.equal(owner.address);
    });

    it("Deve permitir ao proprietário cunhar tokens", async function () {
        const mintAmount = ethers.utils.parseUnits("1000", 10);
        await token.mint(addr1.address, mintAmount);

        expect(await token.balanceOf(addr1.address)).to.equal(mintAmount);
    });

    it("Deve impedir não-proprietários de cunhar tokens", async function () {
        const mintAmount = ethers.utils.parseUnits("1000", 10);
        await expect(token.connect(addr1).mint(addr1.address, mintAmount))
            .to.be.revertedWith("OwnableUnauthorizedAccount");
    });
    
    it("Deve permitir ao proprietário aumentar o nível de um jogador", async function () {
        await token.levelUp(addr1.address);

        const playerData = await token.getPlayerData(addr1.address);
        expect(playerData.level).to.equal(1);

        // Aumentar o nível novamente
        await token.levelUp(addr1.address);
        const updatedPlayerData = await token.getPlayerData(addr1.address);
        expect(updatedPlayerData.level).to.equal(2);
    });

    it("Deve impedir não-proprietários de aumentar o nível de um jogador", async function () {
        await expect(token.connect(addr1).levelUp(addr1.address))
            .to.be.revertedWith("OwnableUnauthorizedAccount");
    });

    it("Deve permitir consultar os dados de um jogador", async function () {
        await token.levelUp(addr1.address);
        const playerData = await token.getPlayerData(addr1.address);
        expect(playerData.level).to.equal(1);
    });

    // Teste integrado para a função burn
    it("Deve permitir que os usuários queimem seus próprios tokens", async function () {
        const mintAmount = ethers.utils.parseUnits("1000", 10);
        await token.mint(addr1.address, mintAmount);

        // Verifica o saldo antes da queima
        expect(await token.balanceOf(addr1.address)).to.equal(mintAmount);

        const burnAmount = ethers.utils.parseUnits("500", 10);
        await token.connect(addr1).burn(burnAmount);

        // Verifica o saldo após a queima
        expect(await token.balanceOf(addr1.address)).to.equal(mintAmount.sub(burnAmount));
    });

    it("Deve impedir que um usuário queime mais tokens do que possui", async function () {
        const mintAmount = ethers.utils.parseUnits("1000", 10);
        await token.mint(addr1.address, mintAmount);

        const burnAmount = ethers.utils.parseUnits("1500", 10);
        await expect(token.connect(addr1).burn(burnAmount))
            .to.be.revertedWith("Insufficient balance to burn");
    });
    
    // Testes para funções do sale
    it("Deve ter salePrice e saleActive inicializados corretamente", async function () {
        // salePrice deve ser 3300000000000 wei conforme definida no contrato e saleActive true
        expect(salePriceInitial).to.equal("3300000000000");
        expect(await token.saleActive()).to.equal(true);
    });

    it("Deve permitir ao proprietário atualizar o salePrice e ajustar o sellPrice para 98% do novo valor", async function () {
        const newSalePrice = ethers.BigNumber.from("5000000000000");
        await expect(token.updateSalePrice(newSalePrice))
            .to.emit(token, "SalePriceUpdated")
            .withArgs(newSalePrice);
        expect(await token.salePrice()).to.equal(newSalePrice);
        // Verifica que sellPrice foi ajustado para 98% do newSalePrice
        expect(await token.sellPrice()).to.equal(newSalePrice.mul(98).div(100));
    });

    it("Deve permitir ao proprietário ativar/desativar a venda", async function () {
        await expect(token.setSaleActive(true))
            .to.emit(token, "SaleStatusUpdated")
            .withArgs(true);
        expect(await token.saleActive()).to.equal(true);

        await expect(token.setSaleActive(false))
            .to.emit(token, "SaleStatusUpdated")
            .withArgs(false);
        expect(await token.saleActive()).to.equal(false);
    });

    it("Deve permitir a compra de tokens convertendo todo ETH enviado em tokens", async function () {
        await token.setSaleActive(true);
        const p = await token.salePrice(); // preço em wei
    
        // Exemplo: para comprar 5 tokens mais um extra de 0.5 tokens (em custo)
        // O valor pago é: 5 * p + (p / 2)
        const tokensBase = 5;
        const extra = p.div(2);
        const paymentValue = p.mul(tokensBase).add(extra);
    
        // Calcula a quantidade de tokens a ser mintada:
        // mintedAmount = (msg.value * 10^18) / salePrice
        const mintedAmount = paymentValue.mul(ethers.BigNumber.from(10).pow(18)).div(p);
    
        const tx = await token.connect(addr1).purchaseTokens({ value: paymentValue });
        const receipt = await tx.wait();
    
        expect(await token.balanceOf(addr1.address)).to.equal(mintedAmount);
    
        const event = receipt.events.find((e) => e.event === "TokensPurchased");
        expect(event.args.tokenAmount).to.equal(mintedAmount);
    });
    
    it("Deve reverter a compra se a venda não estiver ativa", async function () {
        const p = await token.salePrice();
        await token.setSaleActive(false);
    
        await expect(token.connect(addr1).purchaseTokens({ value: p }))
            .to.be.revertedWith("Sale is not active");
    });
    
    it("Deve impedir a compra se nenhum ETH for enviado", async function () {
        await token.setSaleActive(true);
        await expect(token.connect(addr1).purchaseTokens({ value: 0 }))
            .to.be.revertedWith("No ETH sent");
    });
    
    // Teste para a função sellTokens
    it("Deve permitir que um usuário venda tokens e receba ETH pelo SELL_PRICE", async function () {
        await token.setSaleActive(true);
        const p = await token.salePrice();

        // addr1 compra tokens: envia ETH para comprar tokens
        const paymentValue = p.mul(10); // compra tokens com 10 * salePrice
        await token.connect(addr1).purchaseTokens({ value: paymentValue });

        // Obtém o saldo de tokens de addr1
        const tokenBalance = await token.balanceOf(addr1.address);
        // Calcula o valor em ETH que addr1 deverá receber ao vender todos os seus tokens
        const ethExpected = tokenBalance.mul(SELL_PRICE).div(ethers.BigNumber.from(10).pow(18));

        // Registra o saldo de ETH de addr1 antes da venda
        const balanceBeforeSell = await ethers.provider.getBalance(addr1.address);

        // addr1 vende tokens
        const sellTx = await token.connect(addr1).sellTokens(tokenBalance);
        const sellReceipt = await sellTx.wait();
        const gasUsedSell = sellReceipt.gasUsed.mul(sellReceipt.effectiveGasPrice);

        // Verifica se os tokens foram queimados
        expect(await token.balanceOf(addr1.address)).to.equal(0);

        // Verifica o evento TokensSold
        const sellEvent = sellReceipt.events.find((e) => e.event === "TokensSold");
        expect(sellEvent.args.seller).to.equal(addr1.address);
        expect(sellEvent.args.tokenAmount).to.equal(tokenBalance);
        expect(sellEvent.args.ethAmount).to.equal(ethExpected);

        // Verifica o saldo de ETH de addr1 após a venda
        const balanceAfterSell = await ethers.provider.getBalance(addr1.address);
        expect(balanceAfterSell).to.be.closeTo(
            balanceBeforeSell.add(ethExpected).sub(gasUsedSell),
            1000000000
        );
    });
    
    // Teste para a função withdraw
    it("Deve permitir que o owner retire somente o excedente de ETH", async function () {
        await token.setSaleActive(true);
        const p = await token.salePrice();

        // addr1 compra tokens para injetar ETH no contrato
        // Envia 10 * salePrice em ETH
        const paymentValue = p.mul(10);
        await token.connect(addr1).purchaseTokens({ value: paymentValue });
        
        // Calcula a quantidade de tokens em circulação após a compra
        const totalTokens = await token.totalSupply();
        // Calcula a reserva necessária: (totalTokens * SELL_PRICE) / (10^18)
        const requiredBalance = totalTokens.mul(SELL_PRICE).div(ethers.BigNumber.from(10).pow(18));
        // O ETH que pode ser retirado é o excedente: paymentValue - requiredBalance
        const withdrawableExpected = paymentValue.sub(requiredBalance);
        
        // Verifica que o saldo do contrato é igual a paymentValue
        const contractBalanceBefore = await ethers.provider.getBalance(token.address);
        expect(contractBalanceBefore).to.equal(paymentValue);
        
        // Saldo do owner antes da retirada
        const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);
        
        // Owner realiza a retirada
        const withdrawTx = await token.withdraw();
        const withdrawReceipt = await withdrawTx.wait();
        const gasUsedWithdraw = withdrawReceipt.gasUsed.mul(withdrawReceipt.effectiveGasPrice);
        
        // Saldo do contrato depois deve ser igual à reserva (requiredBalance)
        const contractBalanceAfter = await ethers.provider.getBalance(token.address);
        expect(contractBalanceAfter).to.equal(requiredBalance);
        
        // Saldo final do owner deve aumentar pelo valor retirado, menos o gás gasto
        const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);
        expect(ownerBalanceAfter).to.be.closeTo(
            ownerBalanceBefore.add(withdrawableExpected).sub(gasUsedWithdraw),
            1000000000
        );
    });
});