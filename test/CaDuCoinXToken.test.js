// SPDX-License-Identifier: MIT

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CaDuCoinXToken", function () {
    let owner, addr1, addr2, deployer, token, proxy;

    beforeEach(async function () {
        // Obter contas
        [owner, addr1, addr2, deployer] = await ethers.getSigners();

        // Deploy do contrato gamificado
        const TokenGamificado = await ethers.getContractFactory("GameToken");
        tokenGame = await TokenGamificado.deploy();
        await tokenGame.deployed();

        // Deploy do contrato lógico
        const TokenFactory = await ethers.getContractFactory("CaDuCoinXToken");
        token = await TokenFactory.deploy();
        await token.deployed();

        // Inicializar dados para o proxy
        const initializeData = token.interface.encodeFunctionData("initialize", [
            owner.address,
            "CaDuCoinX",
            "CDX",
            tokenGame.address
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
});
