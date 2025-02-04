// SPDX-License-Identifier: MIT

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GameToken", function () {
    let owner, addr1, addr2, gameToken;

    beforeEach(async function () {
        // Obter contas
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy do contrato GameToken
        const GameTokenFactory = await ethers.getContractFactory("GameToken");
        gameToken = await GameTokenFactory.deploy();
        await gameToken.deployed();

        // Inicializar o contrato
        await gameToken.initialize(owner.address);
    });

    it("Deve inicializar corretamente o contrato", async function () {
        expect(await gameToken.owner()).to.equal(owner.address);
    });

    it("Deve permitir ao proprietário aumentar o nível de um jogador", async function () {
        await gameToken.levelUp(addr1.address);

        const playerData = await gameToken.getPlayerData(addr1.address);
        expect(playerData.level).to.equal(1);

        // Aumentar o nível novamente
        await gameToken.levelUp(addr1.address);
        const updatedPlayerData = await gameToken.getPlayerData(addr1.address);
        expect(updatedPlayerData.level).to.equal(2);
    });

    it("Deve impedir não-proprietários de aumentar o nível de um jogador", async function () {
        await expect(gameToken.connect(addr1).levelUp(addr1.address)).to.be.revertedWith(
            "OwnableUnauthorizedAccount"
        );
    });

    it("Deve permitir consultar os dados de um jogador", async function () {
        await gameToken.levelUp(addr1.address);

        const playerData = await gameToken.getPlayerData(addr1.address);
        expect(playerData.level).to.equal(1);
    });
});
