const { ethers } = require("hardhat");

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

    // Validando se é necessário a realização da etapa de deploy
    if(!process.env.LOGIC_CONTRACT_ADDRESS){
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
    }
    
    // Exibir informações do deploy
    console.log("Proxy proxy address:", process.env.PROXY_CONTRACT_ADDRESS);
    console.log("Proxy logic address:", process.env.LOGIC_CONTRACT_ADDRESS);
    console.log("Proxy initialized with:", process.env.INITIALIZE_DATA);
}

// Chamando a função principal com tratamento de erros
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Erro durante o deploy:", error);
        process.exit(1);
    });
