// SPDX-License-Identifier: MIT

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CaDuCoinXToken - Staking", function () {
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

        // Cunhar tokens para testes
        const mintAmount = ethers.utils.parseUnits("10000", 18);
        await token.mint(addr1.address, mintAmount);
        await token.mint(addr2.address, mintAmount);
    });

    it("Deve permitir que um usuário realize um stake", async function () {
        const stakeAmount = ethers.utils.parseUnits("1000", 18);
        const duration = 90 * 24 * 60 * 60; // 3 meses

        // Aprovar o contrato para transferir tokens
        await token.connect(addr1).approve(token.address, stakeAmount);

        // Realizar o stake
        await token.connect(addr1).stake(stakeAmount, duration);

        // Verificar o saldo do contrato
        expect(await token.balanceOf(token.address)).to.equal(stakeAmount);

        // Verificar o saldo do usuário
        expect(await token.balanceOf(addr1.address)).to.equal(
            ethers.utils.parseUnits("9000", 18)
        );
    });
    
    it("Deve permitir que um usuário consulte seus stakes", async function () {
        const stakeAmount1 = ethers.utils.parseUnits("1000", 18);
        const stakeAmount2 = ethers.utils.parseUnits("500", 18);
        const duration1 = 90 * 24 * 60 * 60; // 3 meses
        const duration2 = 180 * 24 * 60 * 60; // 6 meses

        // Aprovar e realizar dois stakes
        await token.connect(addr1).approve(token.address, stakeAmount1);
        await token.connect(addr1).stake(stakeAmount1, duration1);

        await token.connect(addr1).approve(token.address, stakeAmount2);
        await token.connect(addr1).stake(stakeAmount2, duration2);

        // Consultar stakes do usuário
        const userStakes = await token.getUserStakes(addr1.address);

        // Verificar os detalhes dos stakes
        expect(userStakes.length).to.equal(2);
        expect(userStakes[0].amount).to.equal(stakeAmount1);
        expect(userStakes[0].duration).to.equal(duration1);
        expect(userStakes[1].amount).to.equal(stakeAmount2);
        expect(userStakes[1].duration).to.equal(duration2);
    });
});