const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function deployLogicContract() {
    console.log("Deploying CaDuCoinXToken...");
    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    const logic = await CaDuCoinXToken.deploy();
    await logic.deployed();
    console.log("CaDuCoinXToken deployed at:", logic.address);
    return logic;
}

async function deployProxyContract(logicAddress, initializeData) {
    console.log("Deploying CaDuCoinXTokenProxy...");
    const CaDuCoinXTokenProxy = await ethers.getContractFactory("CaDuCoinXTokenProxy");
    const proxy = await CaDuCoinXTokenProxy.deploy(logicAddress, initializeData);
    await proxy.deployed();
    console.log("CaDuCoinXTokenProxy deployed at:", proxy.address);
    return proxy;
}

async function main() {
    // Validando variáveis de ambiente
    if (!process.env.DEPLOYER_ADDRESS || !process.env.NAME_TOKEN || !process.env.SYMBOL) {
        throw new Error("Variáveis de ambiente necessárias não foram definidas.");
    }

    // Deploy do contrato lógico
    const logic = await deployLogicContract();

    // Codificar os dados de inicialização
    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    const initializeData = CaDuCoinXToken.interface.encodeFunctionData("initialize", [
        process.env.DEPLOYER_ADDRESS,
        process.env.NAME_TOKEN,
        process.env.SYMBOL,
    ]);

    // Deploy do proxy
    const proxy = await deployProxyContract(logic.address, initializeData);

    // Salvar endereços dos contratos
    await saveContractAddresses(logic.address, proxy.address, initializeData);

    // Exibir informações do deploy
    console.log("Proxy proxy address:", proxy.address);
    console.log("Proxy logic address:", logic.address);
    console.log("Proxy initialized with:", initializeData);
}

async function saveContractAddresses(logicAddress, proxyAddress, initializeData) {
    const outputDir = path.join(__dirname, "deployments");
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    const logicAddressPath = path.join(outputDir, "deploy_logic_address.txt");
    fs.writeFileSync(logicAddressPath, logicAddress);
    console.log(`Logic contract address saved to: ${logicAddressPath}`);

    const proxyAddressPath = path.join(outputDir, "deploy_proxy_address.txt");
    fs.writeFileSync(proxyAddressPath, proxyAddress);
    console.log(`Proxy contract address saved to: ${proxyAddressPath}`);

    const initDataPath = path.join(outputDir, "deploy_initialize_data.txt");
    fs.writeFileSync(initDataPath, initializeData);
    console.log(`Proxy initialization data saved to: ${initDataPath}`);
}

// Chamando a função principal com tratamento de erros
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Erro durante o deploy:", error);
        process.exit(1);
    });
