# CaDuCoinX (CDX) - Token para Microtransações e Ecossistema Unificado

[![GitHub license](https://img.shields.io/github/license/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/blob/main/LICENSE)  
[![GitHub stars](https://img.shields.io/github/stars/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/stargazers)  
[![GitHub forks](https://img.shields.io/github/forks/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/network/members)

🚀 **CaDuCoinX (CDX)** é um token ERC-20 projetado para revolucionar a economia de microtransações e integrar ecossistemas de jogos. Construído na rede **Optimism**, uma Layer 2 do Ethereum, o CDX combina **taxas baixas**, **transações rápidas** e **sustentabilidade financeira**, proporcionando uma experiência única para desenvolvedores e jogadores.  
O projeto permite que os jogos gerenciem créditos off-chain e os convertam em tokens reais on-chain – sem expor os saldos à volatilidade dos mercados –, além de oferecer marketplaces especializados para NFTs e itens.

---

## 📌 Sumário

1. [Características Principais](#-características-principais)
2. [Funcionalidades do Token](#-funcionalidades-do-token)
3. [Gamificação e Incentivos](#-gamificação-e-incentivos)
4. [Marketplaces Unificados](#-marketplaces-unificados)
   - [NFT Marketplace](#nft-marketplace)
   - [Items Marketplace](#items-marketplace)
5. [Detalhes e Estrutura dos Contratos](#-detalhes-e-estrutura-dos-contratos)
6. [CI/CD](#-cicd)
7. [Roadmap](#-roadmap)
8. [Contribuindo](#-contribuindo)
9. [Licença](#-licença)
10. [Agradecimentos](#-agradecimentos)
11. [Contato](#-contato)

---

## 🚀 Características Principais

- **Microtransações Eficientes:** Aproveite as taxas reduzidas e a alta velocidade da rede Optimism.
- **Integração em Jogos:** Converte créditos off-chain em tokens on-chain, minimizando a exposição à volatilidade dos mercados.
- **Marketplaces Especializados:**  
  - **NFT Marketplace Unificado:** Plataforma para listagem e negociação de NFTs de diversos jogos com o mesmo token.  
  - **Items Marketplace Unificado:** Mercado dedicado à comercialização de itens e outros ativos digitais.
- **Governança e Segurança:** Contratos inteligentes auditáveis e upgradeáveis (padrão UUPS) para robustez e flexibilidade.

---

## ⚡ Funcionalidades do Token

- **Token ERC-20 Upgradável:** Baseado em OpenZeppelin para permitir atualizações futuras sem perda de dados.
- **Mecanismo de Mint e Burn:** Criação e queima controlada de tokens, com limites definidos e regras de AccessControl.
- **Pausabilidade:** Possibilidade de interromper operações críticas em situações de emergência.
- **Integração com Gamificação:**  
  - Funções internas de levelUp e armazenamento de dados (níveis) dos jogadores.
- **Deploy Automatizado:** Suporte para Hardhat, rede OP Sepolia e integração contínua via GitHub Actions.

---

## 🎮 Gamificação e Incentivos

O ecossistema CaDuCoinX promove programas de fidelidade e recompensas para incentivar jogadores e desenvolvedores:
- **Programas de Pontos e Créditos Off-Chain:** Jogos podem gerenciar créditos internamente e convertê-los em tokens quando necessário.
- **Campanhas de Engajamento:** Bonificações e recompensas personalizadas conforme o desempenho dos jogadores.
- **Facilidade de Integração:** SDKs e APIs disponíveis para sincronizar dados off-chain com as transações on-chain.

---

## 🛒 Marketplaces Unificados

O ecossistema conta com marketplaces especializados para ativos digitais:

### NFT Marketplace
- Plataforma centralizada para listagem e negociação de NFTs de vários jogos.
- Transações realizadas utilizando o mesmo token, promovendo interoperabilidade e liquidez.

### Items Marketplace
- Mercado dedicado à comercialização de itens e ativos digitais não-NFT.
- Regras customizadas para precificação e integração com sistemas de jogos.

---

## 📜 Detalhes e Estrutura dos Contratos

- **CaDuCoinXToken:**  
  - Baseado em ERC-20 com funcionalidades integradas de gamificação (levelUp, dados dos jogadores) e controle de mint/burn via AccessControl.  
  - Utiliza o padrão UUPS para upgrade com proxy.

- **NFTMarketplaceUnified:**  
  - Contrato upgradeable para listagem, compra e delistagem de NFTs.  
  - Implementa a interface `IMarketplace` para operações padronizadas.

- **ItemsMarketplaceUnified:**  
  - Contrato upgradeable dedicado à comercialização de itens.  
  - Também implementa a interface `IMarketplace`.

- **CaDuCoinXSaleUSDC:**  
  - Permite a venda direta de tokens utilizando USDC.  
  - Configurado para que 1 token custe 0,0086 USDC (tokenPrice = 8600, considerando USDC com 6 decimais).

- **CaDuCoinXTokenProxy:**  
  - Proxy para o contrato CaDuCoinXToken, permitindo upgrades sem perda de dados.

---

## 🔄 CI/CD

O repositório conta com um fluxo de GitHub Actions configurado em `.github/workflows/main.yml` para deploy automatizado, testes e integração contínua na rede OP Sepolia.

---

## 🛣️ Roadmap

### **Q1: Lançamento do Token**
- Deploy inicial do contrato CaDuCoinXToken na rede Optimism.
- Parcerias com early adopters e integração piloto com jogos.

### **Q2: Integração em Jogos**
- Implementação do fluxo off-chain para conversão de créditos em tokens.
- Lançamento do SDK para integração dos sistemas de gamificação e fidelidade.
- Deploy do contrato CaDuCoinXSaleUSDC para venda direta de tokens via USDC.

### **Q3: Expansão do Ecossistema**
- Desenvolvimento e lançamento dos marketplaces (NFT e Items Unificados).  
- Parcerias estratégicas para ampliar o alcance do ecossistema.

### **Q4: Escalabilidade e Novos Mercados**
- Integração com plataformas de streaming e entretenimento.
- Funcionalidades adicionais (royalties, leilões, etc.) nos marketplaces.
- Expansão para outras redes, como Polygon e Solana.

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