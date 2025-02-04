# CaDuCoinX (CDX) - Token para Microtransações e Ecossistema Unificado

[![GitHub license](https://img.shields.io/github/license/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/network/members)

🚀 O **CaDuCoinX (CDX)** é um token ERC-20 projetado para revolucionar a economia de microtransações e integrar ecossistemas de jogos. Construído na rede **Optimism**, uma Layer 2 de Ethereum, o CDX combina **baixos custos de transação**, **alta velocidade** e **sustentabilidade financeira**, proporcionando uma experiência única para desenvolvedores e jogadores. O projeto permite que jogos gerenciem créditos internamente e convertam esses créditos em tokens reais on-chain – sem necessidade de expor seus saldos à volatilidade dos mercados secundários.

---

## 📌 Sumário

1. [Características Principais](#-características-principais)
2. [Funcionalidades do Token](#-funcionalidades-do-token)
3. [Gamificação e Incentivos](#-gamificação-e-incentivos)
4. [Marketplace Unificado de NFTs](#-marketplace-unificado-de-nfts)
5. [Como Utilizar o CaDuCoinX](#-como-utilizar-o-caducoinx)
6. [Deploy dos Contratos](#-deploy-dos-contratos)
7. [Detalhes e Estrutura dos Contratos](#-detalhes-e-estrutura-dos-contratos)
8. [CI/CD](#-cicd)
9. [Roadmap](#-roadmap)
10. [Contribuindo](#-contribuindo)
11. [Licença](#-licença)
12. [Agradecimentos](#-agradecimentos)
13. [Contato](#-contato)

---

## 🚀 Características Principais

- **Microtransações Baratas e Rápidas**: Com taxas reduzidas na rede Optimism, o CDX é ideal para operações frequentes e de pequenos valores.
- **Integração em Jogos e Aplicativos**: Permite que os jogos gerenciem créditos off-chain e só convertem para tokens on-chain quando necessário.
- **Marketplace Unificado de NFTs**: Uma plataforma centralizada em que NFTs de diversos jogos podem ser listados e comercializados, usando o mesmo token para facilitar a interoperabilidade.
- **Governança e Segurança**: Contrato inteligente auditável, utilizando padrões upgradeáveis via OpenZeppelin e UUPS para garantir flexibilidade e transparência.

---

## ⚡ Funcionalidades do Token

- **Token ERC-20 Upgradável**: Permite atualizações futuras sem comprometer os dados.
- **Mecanismo de Burn e Mint**: Criação e queima controlada de tokens, conforme demanda dos parceiros.
- **Pausabilidade**: Possibilidade de pausar operações críticas em situações de emergência.
- **Deploy Automatizado**: Suporte para Hardhat, Sepolia e integração com GitHub Actions.
- **Integração com Gamificação**: Funcionalidades que se interligam a sistemas off-chain de recompensa e fidelidade, sem sobrecarregar a liquidez.

---

## 🎮 Gamificação e Incentivos

O CaDuCoinX promove um ecossistema em que programas de fidelidade e recompensas incentivam tanto os jogadores quanto os desenvolvedores sem impactar diretamente a liquidez on-chain.  
Algumas estratégias incluem:

- **Programas de Pontos e Créditos Off-Chain**: Jogos podem criar sistemas internos para premiar jogadores com pontos que podem ser convertidos em benefícios ou descontos para aquisição de tokens.
- **Campanhas Baseadas em Engajamento**: Bonificações e recompensas personalizadas, conforme o desempenho e fidelidade dos usuários.
- **Integração Simples via SDK**: Ferramentas para que desenvolvedores integrem facilmente os sistemas de gamificação e fidelidade, sincronizando dados off-chain com transações on-chain quando necessário.

---

## 🖼️ Marketplace Unificado de NFTs

Crie e participe de um ecossistema colaborativo onde:

- NFTs de diversos jogos são listados em uma única plataforma.
- Uma única conta pode armazenar e gerenciar ativos de múltiplos jogos.
- As transações são realizadas com o mesmo token, garantindo uma economia unificada e estável.
- Essa abordagem elimina a complicação de lidar com múltiplas moedas e expõe os ativos a um mercado com maior liquidez.

---

## 📖 Como Utilizar o CaDuCoinX

### 1️⃣ Instalação

Para começar a contribuir ou utilizar o projeto, siga os passos abaixo:

```bash
git clone https://github.com/Eduhkbr/CaDuCoinX.git
cd CaDuCoinX
npm install
```

### 2️⃣ Configuração

Crie um arquivo `.env` com as seguintes variáveis:

```env
PRIVATE_KEY=your_private_key
INFURA_SEPOLIA_URL=your_infura_url
DEPLOYER_ADDRESS=your_deployer_address
TAX_ADDRESS=your_tax_address
NAME_TOKEN="CaDuCoinX"
SYMBOL="CDX"
```


---

## 🛠️ Deploy dos Contratos

- **Para implantar os contratos na rede Sepolia, execute:**: 
```
npx hardhat run scripts/deploy.js --network sepolia
```

---

## 📜 Detalhes do Contrato

- **Contract Address**: `0x...`
- **Rede**: Optimism (Chain ID: 69)
- **Etherscan**: [Verificar no Etherscan](#)

---

## 📜 Estrutura dos Contratos

- **Baseado no ERC-20 da OpenZeppelin com funcionalidades adicionais de staking e burn/mint.**
- **Utiliza padrões de contrato upgradável da OpenZeppelin**
- **Implementa o padrão de proxy UUPS para permitir upgrades futuros**

---


## 🔄 CI/CD

- O repositório inclui um fluxo de GitHub Actions (`.github/workflows/main.yml`) para deploy automatizado na rede Sepolia.

---

## 🛣️ Roadmap

### **Q1: Lançamento do Token**
- Lançamento do contrato inteligente na rede Optimism.
- Parceria com early adopters e integração inicial com jogos-piloto.

### **Q2: Integração em Jogos**
- Implementação do fluxo off-chain para conversão de créditos em tokens.
- Lançamento do SDK para integração dos sistemas de fidelidade e gamificação.
- Implementação do contrato de venda direta com USDC.

### **Q3: Expansão do Ecossistema**
- Desenvolvimento e lançamento do marketplace que agrega NFTs de diversos jogos.
- Parcerias estratégicas para ampliação do ecossistema.

### **Q4: Escalabilidade e Novos Mercados**
- Integração com plataformas de streaming e entretenimento.
- Evolução do ecossistema com funcionalidades adicionais (royalties, leilões, etc.).
- Expansão para outras redes (ex: Polygon, Solana).

---

## 🤝 Contribuindo

1. Fork o repositório.
2. Crie uma branch para suas alterações:

   ```bash
   git checkout -b feature/nova-funcionalidade
   ```

3. Commit suas alterações:

   ```bash
   git commit -m "Adicionada nova funcionalidade"
   ```

4. Push para a branch:

   ```bash
   git push origin feature/nova-funcionalidade
   ```

5. Abra um Pull Request.

---

## 📜 Licença

Este projeto está licenciado sob a **Licença MIT** - veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

## 🎉 Agradecimentos

Agradecemos à equipe do **OpenZeppelin** por seus contratos seguros e bem testados.

A todos os **contribuidores** que ajudaram a tornar o **CaDuCoinX** uma realidade.

---

## 📩 Contato

📧 **Email**: contato@caducoinx.io  
🐦 **Twitter**: [@CaDuCoinX](#)  
💬 **Discord**: [Comunidade CaDuCoinX](#)  
📢 **Telegram**: [Grupo CaDuCoinX](#)