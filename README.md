# CaDuCoinX (CDX) - Token para Microtransações e Staking

[![GitHub license](https://img.shields.io/github/license/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/network/members)

🚀 O **CaDuCoinX (CDX)** é um token ERC-20 projetado para revolucionar a economia de microtransações e oferecer uma nova forma de gerar rendimento através de staking. Construído na rede **Optimism**, uma Layer 2 de Ethereum, o CDX combina **baixos custos de transação**, **alta velocidade** e **sustentabilidade financeira** para criar uma experiência única no mercado de criptomoedas.

---

## 📌 Sumário

1. [Características Principais](#-características-principais)
2. [Funcionalidades do Token](#-funcionalidades-do-token)
3. [Gamificação](#-gamificação)
4. [Como Utilizar o CaDuCoinX](#-como-utilizar-o-caducoinx)
5. [Deploy dos Contratos](#-deploy-dos-contratos)
6. [Detalhes e Estrutura dos Contratos](#-detalhes-e-estrutura-dos-contratos)
7. [CI/CD](#-cicd)
8. [Roadmap](#-roadmap)
9. [Contribuindo](#-contribuindo)
10. [Licença](#-licença)
11. [Agradecimentos](#-agradecimentos)
12. [Contato](#-contato)

---

## 🚀 Características Principais

- **Microtransações Baratas e Rápidas**: Com taxas de gás reduzidas na rede Optimism, o CDX é ideal para transações frequentes e pequenas.
- **Staking com Rendimentos Atrativos**: Stake seu CDX por 3, 6, 9 ou 12 meses e ganhe recompensas de 4% a 10% ao ano.
- **Integração em Jogos e Aplicativos**: Projeto gamificado para ser utilizado em jogos e plataformas de entretenimento.
- **Governança e Segurança**: Contrato inteligente auditável e totalmente transparente.

---

## ⚡ Funcionalidades do Token

- **Token ERC-20 Upgradável**: Utiliza OpenZeppelin para permitir atualizações via proxy.
- **Staking com Recompensas**: Usuários podem bloquear tokens por períodos pré-determinados para receber recompensas.
- **Taxa de Juros Dinâmica**: O proprietário pode ajustar a taxa de juros anual entre 4% e 10%.
- **Pausabilidade**: O contrato pode ser pausado para evitar operações indesejadas.
- **Mecanismo de Burn e Mint**: Tokens podem ser criados ou queimados pelo proprietário.
- **Deploy Automatizado**: Suporte para Hardhat, Sepolia e integração com GitHub Actions.
- **Gamificação**: Sistema de conquistas e recompensas baseado no engajamento dos usuários com staking e transações.

---

## 🎮 Gamificação

O CaDuCoinXToken implementa um sistema de gamificação para incentivar a participação ativa dos usuários. As principais mecânicas incluem:

- **Níveis de Staking**: Usuários acumulam experiência ao manter tokens bloqueados, subindo de nível para desbloquear melhores taxas de recompensa.
- **Missões e Desafios**: Completar ações como staking contínuo por X dias ou realizar Y transações pode render tokens de bônus.
- **Badges e Conquistas**: Usuários ganham distintivos por marcos atingidos, como primeiro staking, primeiro milhão de tokens movimentado, entre outros.
- **Ranking de Usuários**: Um leaderboard exibe os usuários mais ativos e engajados na plataforma.
- **Sistema de Cashback**: Parte das taxas geradas pode ser redistribuída como cashback para os usuários mais engajados.


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
- Listagem em pequenas exchanges e DEXs.

### **Q2: Integração em Jogos**
- Parcerias com estúdios de jogos independentes.
- Lançamento de um jogo piloto utilizando o CDX.

### **Q3: Expansão do Ecossistema**
- Integração com plataformas de streaming e entretenimento.
- Desenvolvimento de uma wallet oficial do projeto.

### **Q4: Escalabilidade e Novos Mercados**
- Expansão para outras redes (ex: Polygon, Solana).
- Entrada em mercados emergentes e tradicionais.

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