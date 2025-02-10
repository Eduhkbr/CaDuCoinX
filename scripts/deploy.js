const { deploy } = require("@openzeppelin/hardhat-upgrades/dist/utils");
const { ethers, upgrades } = require("hardhat");


async function deployItemsMarketplaceUnifiedContract(logicAddress) {
    console.log("Deploying ItemsMarketplaceUnified logic contract...");
    const ItemsMarketplaceUnified = await ethers.getContractFactory("ItemsMarketplaceUnified");
    // Inicializa com (paymentTokenAddress, owner)
    const marketplace = await upgrades.deployProxy(
        ItemsMarketplaceUnified,
        [logicAddress, process.env.DEPLOYER_ADDRESS],
        { initializer: "initialize" }
    );
    await marketplace.deployed();
    console.log("ItemsMarketplaceUnified contract deployed at:", marketplace.address);
    return marketplace;
}

async function deployNFTMarketplaceUnifiedContract(logicAddress) {
    console.log("Deploying NFTMarketplaceUnified logic contract...");
    const NFTMarketplaceUnified = await ethers.getContractFactory("NFTMarketplaceUnified");
    // Inicializa com (paymentTokenAddress, owner)
    const marketplace = await upgrades.deployProxy(
        NFTMarketplaceUnified,
        [logicAddress, process.env.DEPLOYER_ADDRESS],
        { initializer: "initialize" }
    );
    await marketplace.deployed();
    console.log("NFTMarketplaceUnified contract deployed at:", marketplace.address);
    return marketplace;
}

async function deployLogicContract() {
    console.log("Deploying CaDuCoinXToken logic contract...");
    const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
    const logic = await CaDuCoinXToken.deploy();
    await logic.deployed();
    console.log("CaDuCoinXToken logic contract deployed at:", logic.address);
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
    // Valida as variáveis de ambiente necessárias para o token
    if (!process.env.DEPLOYER_ADDRESS || !process.env.NAME_TOKEN || !process.env.SYMBOL) {
        throw new Error("Variáveis de ambiente necessárias não foram definidas: DEPLOYER_ADDRESS, NAME_TOKEN e SYMBOL.");
    }
    
    // Se não houver um endereço do contrato lógico pré-existente, realize o deploy de todos os contratos
    if (!process.env.LOGIC_CONTRACT_ADDRESS) {
        // Deploy do contrato lógico do token
        const logic = await deployLogicContract();

        // Codificar dados de inicialização para o token: initialize(owner, name, symbol)
        const CaDuCoinXToken = await ethers.getContractFactory("CaDuCoinXToken");
        const initializeData = CaDuCoinXToken.interface.encodeFunctionData("initialize", [
            process.env.DEPLOYER_ADDRESS,
            process.env.NAME_TOKEN,
            process.env.SYMBOL
        ]);
        
        // Deploy do proxy do token
        const proxy = await deployProxyContract(logic.address, initializeData);

        let nftMarketplace;
        let itemsMarketplace
        if(!process.env.NTF_CONTRACT_ADDRESS || !process.env.ITEM_CONTRACT_ADDRESS) {

            // Deploy do contrato NFTMarketplaceUnified
            nftMarketplace = await deployNFTMarketplaceUnifiedContract(logic.address);

            // Deploy do contrato NFTMarketplaceUnified
            itemsMarketplace = await deployItemsMarketplaceUnifiedContract(logic.address);
        }else{
            nftMarketplace = process.env.NTF_CONTRACT_ADDRESS;
            itemsMarketplace = process.env.ITEM_CONTRACT_ADDRESS;
        }

        console.log("Deployment summary:");
        console.log("CaDuCoinXToken Logic Address:", logic.address);
        console.log("CaDuCoinXToken Proxy Address:", proxy.address);
        console.log("NFTMarketplaceUnified Address:", nftMarketplace.address);
        console.log("ItemsMarketplaceUnified Address:", itemsMarketplace.address);
        console.log("Token initialized with:", initializeData);
    } else {
        console.log("Contracts already deployed:");
        console.log("CaDuCoinXToken Logic Address:", process.env.LOGIC_CONTRACT_ADDRESS);
        console.log("CaDuCoinXToken Proxy Address:", process.env.PROXY_CONTRACT_ADDRESS);
        console.log("NFTMarketplaceUnified Address:", process.env.NTF_CONTRACT_ADDRESS);
        console.log("ItemsMarketplaceUnified Address:", process.env.ITEM_CONTRACT_ADDRESS);
        console.log("Token initialized with:", process.env.INITIALIZE_DATA);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("Erro durante o deploy:", error);
        process.exit(1);
    });
