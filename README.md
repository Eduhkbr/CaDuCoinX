# CaDuCoinX (CDX) - Token para Microtransações e Ecossistema Unificado

[![GitHub license](https://img.shields.io/github/license/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/blob/main/LICENSE)  
[![GitHub stars](https://img.shields.io/github/stars/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/stargazers)  
[![GitHub forks](https://img.shields.io/github/forks/Eduhkbr/CaDuCoinX)](https://github.com/Eduhkbr/CaDuCoinX/network/members)

**CaDuCoinX (CDX)** é um token ERC‑20 upgradeável projetado para revolucionar a economia de microtransações e integrar ecossistemas de jogos. Construído na rede **Optimism** (Layer 2 do Ethereum), o CDX oferece transações rápidas, taxas baixas e alta segurança, permitindo a conversão de créditos off‑chain em tokens on‑chain de forma eficiente. O ecossistema também conta com marketplaces especializados para NFTs e itens digitais, promovendo interoperabilidade e liquidez entre diferentes jogos e plataformas.

---

## 📌 Sumário

1. [Características Principais](#-características-principais)
2. [Funcionalidades do Token](#-funcionalidades-do-token)
3. [Marketplaces Unificados](#-marketplaces-unificados)
   - [NFT Marketplace Unificado](#nft-marketplace-unificado)
   - [Items Marketplace Unificado](#items-marketplace-unificado)
4. [Detalhes e Estrutura dos Contratos](#-detalhes-e-estrutura-dos-contratos)
5. [CI/CD](#-cicd)
6. [Roadmap](#-roadmap)
7. [Contribuindo](#-contribuindo)
8. [Licença](#-licença)
9. [Agradecimentos](#-agradecimentos)
10. [Contato](#-contato)

---

## 🚀 Características Principais

- **Microtransações Eficientes:**  
  Aproveite as taxas reduzidas e a alta velocidade proporcionadas pela rede Optimism.

- **Integração com Jogos:**  
  Converta créditos off‑chain em tokens on‑chain de forma simples e segura, minimizando a exposição à volatilidade dos mercados.

- **Marketplaces Integrados:**  
  - **NFT Marketplace Unificado:** Plataforma para listagem e negociação de NFTs entre diversos jogos, com custódia (escrow) segura dos ativos.  
  - **Items Marketplace Unificado:** Ambiente dedicado à comercialização de itens e ativos digitais não‑NFT.

- **Upgradeabilidade e Segurança:**  
  Contratos inteligentes seguros, auditados e atualizáveis (padrão UUPS), com arquitetura robusta para evitar vulnerabilidades comuns.

---

## ⚡ Funcionalidades do Token

- **Token ERC‑20 Upgradeável:**  
  Implementado com os contratos da OpenZeppelin, permitindo atualizações sem perda do estado.

- **Mint & Burn Controlados:**  
  Emissão e queima de tokens com limites máximos definidos para garantir o equilíbrio do ecossistema.

- **Compra & Venda com ETH:**  
  - **Compra (`purchaseTokens`)**: Usuários podem adquirir tokens enviando ETH explicitamente via função pública; a quantidade a ser mintada é calculada com base no valor enviado e no preço corrente (`salePrice`).  
  - **Venda (`sellTokens`)**: Permite que tokens sejam vendidos de volta ao contrato, queimando-os e recebendo ETH, desde que o contrato possua saldo suficiente.
  - **Depósito de ETH (`depositEth`)**: Apenas administradores podem depositar ETH para garantir liquidez para vendas de tokens.

- **Atualização de Preço:**  
  O owner pode ajustar o preço de venda dos tokens por meio da função `updateSalePrice`.

- **Retirada de Fundos:**  
  Função `withdraw` que possibilita ao owner sacar o excesso de ETH acumulado, mantendo uma reserva para garantir transações seguras. Saques emergenciais exigem que o contrato esteja pausado.

- **Pausabilidade:**  
  Mecanismo para pausar operações críticas em situações de emergência.

- **Boas Práticas de Upgrade:**  
  Uso de storage gap (`__gap`) para garantir segurança em futuras atualizações.

---

## 🛒 Marketplaces Unificados

O ecossistema conta com duas soluções de marketplace para facilitar a negociação de ativos digitais:

### NFT Marketplace Unificado

- Plataforma centralizada para listagem, compra e delistagem de NFTs.
- **Padrão Escrow:** O NFT é transferido para o contrato do marketplace no momento da listagem e só é liberado ao comprador ou devolvido ao vendedor em caso de delist.
- Operações realizadas utilizando o mesmo token (CDX), promovendo interoperabilidade entre jogos e projetos.
- Prevenção de listagem duplicada e proteção contra fraudes.

### Items Marketplace Unificado

- Mercado dedicado à comercialização de itens e ativos digitais não‑NFT.
- Regras customizadas para precificação e integração com sistemas de jogos, garantindo transações seguras e eficientes.
- Taxa de marketplace deduzida do vendedor, nunca adicionada ao preço para o comprador.
- Itens deliberadamente removidos não podem ser reativados por engano.

---

## 📜 Detalhes e Estrutura dos Contratos

- **CaDuCoinXToken:**  
  - Contrato ERC‑20 upgradeável com funcionalidades de mint & burn, compra e venda com ETH, atualização de preços e pausabilidade.  
  - Funções principais:
    - `purchaseTokens`
    - `sellTokens`
    - `updateSalePrice`
    - `withdraw`
    - `depositEth`
  - Implementado utilizando o padrão UUPS para permitir upgrades sem perda de dados.
  - **Importante:** Não há mais gamificação ou armazenamento de dados de jogador neste contrato.

- **CaDuCoinXTokenProxy:**  
  - Proxy baseado no padrão ERC1967 que delega chamadas para o contrato CaDuCoinXToken, possibilitando atualizações futuras sem alteração do estado.
  - Não aceita ETH diretamente; todas as operações devem ser feitas via funções explícitas do token.

- **NFTMarketplaceUnified:**  
  - Contrato upgradeável para listar, comprar e delistar NFTs, utilizando padrão escrow para máxima segurança.
  - O NFT é transferido para o contrato do marketplace durante a listagem e só sai de lá em caso de compra ou delist.
  - Não implementa mais a interface `IMarketplace` (incompatível com NFTs).

- **ItemsMarketplaceUnified:**  
  - Contrato upgradeável dedicado à negociação de itens e ativos digitais não‑NFT.
  - Taxas e lógica de listagem otimizadas para segurança e clareza.
  - Itens deliberadamente removidos não podem ser reativados por engano.

---

## 🔄 CI/CD

- O projeto utiliza GitHub Actions para integração contínua e deploy automatizado, conforme configurado no arquivo [.github/workflows/main.yml](.github/workflows/main.yml).
- O fluxo de deploy utiliza Hardhat juntamente com o plugin OpenZeppelin Upgrades para implantar os contratos na rede Optimism.
- As variáveis de ambiente (como `PRIVATE_KEY`, `INFURA_SEPOLIA_URL`, `DEPLOYER_ADDRESS`, etc.) garantem uma implantação segura e customizável.  
  *Nota:* Embora haja menção à variável `INFURA_SEPOLIA_URL`, o deploy é direcionado para a rede Optimism (chainId: 11155420).

---

## 🛣️ Roadmap

### Q1: Lançamento do Token
- Deploy inicial do contrato CaDuCoinXToken na rede Optimism.
- Estabelecimento de parcerias com early adopters e integração piloto com jogos.

### Q2: Integração com Jogos e Inovação
- Implementação do fluxo off‑chain para conversão de créditos em tokens.
- Lançamento do SDK de integração para sistemas de gamificação e fidelidade.

### Q3: Expansão do Ecossistema
- Desenvolvimento e lançamento dos marketplaces unificados (NFT e Items).
- Novas parcerias estratégicas para ampliar a adoção do ecossistema.

### Q4: Escalabilidade e Novos Mercados
- Integração com plataformas de streaming e entretenimento.
- Adição de novas funcionalidades (como royalties e leilões) nos marketplaces.
- Expansão para outras redes, como Polygon e Solana.

---

## 🤝 Contribuindo

1. Faça um **fork** do repositório.  
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