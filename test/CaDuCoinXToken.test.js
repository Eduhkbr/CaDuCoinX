// SPDX-License-Identifier: MIT

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CaDuCoinXToken", function () {
    let owner, addr1, addr2, deployer, token, proxy;

    beforeEach(async function () {
        // Obter contas
        [owner, addr1, addr2, deployer] = await ethers.getSigners();

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

        // Deploy do proxy
        const ProxyFactory = await ethers.getContractFactory("CaDuCoinXTokenProxy");
        proxy = await ProxyFactory.deploy(token.address, initializeData);
        await proxy.deployed();

        // Conectar o contrato lógico ao proxy
        token = TokenFactory.attach(proxy.address);
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
        await expect(token.connect(addr1).mint(addr1.address, mintAmount)).to.be.revertedWith("Not authorized to mint");
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
        await expect(token.connect(addr1).levelUp(addr1.address)).to.be.revertedWith(
            "OwnableUnauthorizedAccount"
        );
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
        await expect(token.connect(addr1).burn(burnAmount)).to.be.revertedWith("Insufficient balance to burn");
    });
});
