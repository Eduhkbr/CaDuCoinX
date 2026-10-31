# CaDuCoinX (CDX)

CaDuCoinX é um protótipo de token ERC-20 com staking e um marketplace de NFTs em CDX. O alvo de produção pretendido é Optimism; o único alvo de deploy automatizado neste repositório é **Optimism Sepolia**. O projeto ainda não tem auditoria formal nem deploy de produção verificado.

## Estado implementado

- ERC-20 com supply máximo de 21 milhões de CDX, mint administrativo sujeito ao cap e burn voluntário do próprio holder.
- Staking por 90, 180, 270 ou 365 dias. A APR é expressa em basis points (`600 = 6%`, faixa configurável de 4,2% a 10%) e fica fixada no início do stake. O contrato reserva o reward no cap; se não houver capacidade suficiente, um novo stake é recusado. O principal e o reward reservado continuam sacáveis depois da maturidade, inclusive durante pausa.
- Pausa administrativa bloqueia mint, novos stakes, listagens e compras. Transfers ERC-20, cancelamento de listagens e saques maduros continuam disponíveis.
- Escrow de NFTs: o vendedor deposita o NFT e define um preço positivo em CDX. A compra paga o vendedor pelo preço registrado; o vendedor pode cancelar e recuperar o NFT.
- `GameToken` mantém apenas níveis de jogadores. Missões, badges, rankings, cashback e recompensas de jogo não estão implementados.
- `purchaseItem` permanece experimental: os tokens recebidos ficam no contrato e não há fluxo de liquidação/retirada. Não use essa função até que esse fluxo seja implementado.

O owner controla mint, taxa, pausa e upgrades. Em produção, o owner deve ser uma multisig. A pausa não congela transfers ERC-20.

## Redes

| Rede | Chain ID | Uso neste projeto |
| --- | ---: | --- |
| Optimism Sepolia | 11155420 | Testnet configurada para deploy manual |
| Optimism mainnet | 10 | Alvo pretendido; deploy não configurado nem autorizado por este repositório |
| Ethereum Sepolia | 11155111 | Não é o alvo configurado |

## Desenvolvimento

Requer Node.js 24 e npm. O compilador Solidity 0.8.28 vem do lockfile npm para evitar download não verificado durante a compilação.

```bash
npm ci
npm run compile
npm test
```

`./run_hardhat.sh` executa compilação e testes. Os testes usam a rede local do Hardhat e não precisam de chave ou RPC.

## Deploy de testnet

Configure os valores no ambiente protegido `optimism-sepolia` do GitHub Actions ou no ambiente local:

```env
PRIVATE_KEY=chave_da_conta_de_deploy
OPTIMISM_SEPOLIA_RPC_URL=https://rpc-da-optimism-sepolia
CDX_ADMIN_ADDRESS=0x...
NAME_TOKEN=CaDuCoinX
SYMBOL=CDX
```

`CDX_ADMIN_ADDRESS` recebe o controle administrativo do proxy. Não registre valores secretos no repositório. O script verifica o chain ID antes de enviar transações e transfere o ownership do GameToken ao proxy CDX.

Para deploy manual, execute `npm run deploy:testnet`. O workflow também compila, executa testes e verifica advisories altos/críticos antes de deploy. O job exige `workflow_dispatch`, execução na branch `main`, confirmação explícita e aprovação do ambiente protegido. Não existe job de deploy automático em push ou PR.

## Upgradeability e segurança

O CDX usa proxy UUPS validado pelo plugin OpenZeppelin; a implementação bloqueia inicialização direta. Alterações de storage exigem revisão e testes de upgrade antes de qualquer contrato ser publicado.

Este repositório não é uma auditoria de segurança. Não use fundos reais nem trate APR, marketplace ou governança como auditados. Consulte [ROADMAP.md](ROADMAP.md) para riscos conhecidos, validações e backlog.
