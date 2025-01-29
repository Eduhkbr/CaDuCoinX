const { ethers } = require("hardhat");

async function verifyContract(contractAddress, constructorArgs = []) {
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: constructorArgs,
        });
        console.log(`Contract at ${contractAddress} verified successfully!`);
    } catch (error) {
        console.error(`Verification failed for contract at ${contractAddress}:`, error);
    }
}

async function main() {
    if (!process.env.LOGIC_CONTRACT_ADDRESS || !process.env.PROXY_CONTRACT_ADDRESS || !process.env.ADMIN_ADDRESS) {
        throw new Error("Variáveis de ambiente necessárias não foram definidas.");
    }

    // Verificar contrato lógico
    await verifyContract(process.env.LOGIC_CONTRACT_ADDRESS);

    // Argumentos do construtor do proxy (endereço da lógica e do administrador)
    const constructorArgs = [
        process.env.LOGIC_CONTRACT_ADDRESS,
        process.env.ADMIN_ADDRESS,
    ];

    // Verificar contrato proxy
    await verifyContract(process.env.PROXY_CONTRACT_ADDRESS, constructorArgs);

    console.log("Verification completed for both contracts.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Erro durante a verificação:", error);
        process.exit(1);
    });
