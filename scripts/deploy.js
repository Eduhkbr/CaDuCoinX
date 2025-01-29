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

async function verifyContract(contractAddress, logicAddress, initializeData) {
    console.log("Verifying contract...");
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: [logicAddress, initializeData],
        });
        console.log("Contract verified successfully!");
    } catch (error) {
        console.error("Verification failed:", error);
    }
}


async function verifyContract(contractAddress) {
    console.log("Verifying contract...");
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: [],
        });
        console.log("Contract verified successfully!");
    } catch (error) {
        console.error("Verification failed:", error);
    }
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


    // Verificar o contrato proxy
    const verificationLogic = await verifyContract(logic.address);

    // Verificar o contrato proxy
    const verificationProxy = await verifyContract(proxy.address, logic.address, initializeData);

    // Exibir informações do deploy
    console.log("Proxy logic address:", logic.address);
    console.log("Proxy initialized with:", initializeData);
    
    console.log("Verificação logic etherscan:", verificationLogic);
    console.log("Verificação proxy etherscan:", verificationProxy);
}

// Chamando a função principal com tratamento de erros
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Erro durante o deploy:", error);
        process.exit(1);
    });
