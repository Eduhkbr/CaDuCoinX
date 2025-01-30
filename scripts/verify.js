const { Etherscan } = require("@nomicfoundation/hardhat-verify/etherscan");

async function verifyContract(instance, contractAddress, constructorArgs = []) {
    try {
        await instance.verify(contractAddress, constructorArgs);
        console.log(`Contract at ${contractAddress} verified successfully!`);
    } catch (error) {
        console.error(`Verification failed for contract at ${contractAddress}:`, error);
        throw error;
    }
}

async function main() {
    if (!process.env.ETHERSCAN_API_KEY ||
        !process.env.LOGIC_CONTRACT_ADDRESS ||
        !process.env.PROXY_CONTRACT_ADDRESS ||
        !process.env.ADMIN_ADDRESS ||
        !process.env.INITIALIZE_DATA) {
        throw new Error("Variáveis de ambiente necessárias não foram definidas.");
    }

    // Configurar a instância do Etherscan
    const etherscanInstance = new Etherscan(
        process.env.ETHERSCAN_API_KEY,
        "https://api-sepolia.etherscan.io/api",
        "https://sepolia.etherscan.io"
    );

    // Verificar contrato lógico
    await verifyContract(etherscanInstance, process.env.LOGIC_CONTRACT_ADDRESS);

    // Argumentos do construtor do proxy (endereço da lógica e do administrador)
    const constructorArgs = [
        process.env.LOGIC_CONTRACT_ADDRESS,
        process.env.ADMIN_ADDRESS,
    ];

    // Verificar contrato proxy
    await verifyContract(etherscanInstance, process.env.PROXY_CONTRACT_ADDRESS, constructorArgs);

    console.log("Verification completed for both contracts.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Erro durante a verificação:", error);
        process.exit(1);
    });
