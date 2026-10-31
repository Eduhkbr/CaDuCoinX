# CaDuCoinX (CDX)

CaDuCoinX é um protótipo de token ERC-20 com staking e um marketplace de NFTs em CDX. O alvo de produção pretendido é Optimism; o único alvo de deploy automatizado neste repositório é **Optimism Sepolia**. O projeto ainda não tem auditoria formal nem deploy de produção verificado.

## Estado implementado

- ERC-20 com supply máximo de 1 bilhão de CDX, mint administrativo sujeito ao cap e burn voluntário do próprio holder.
- Compra primária a preço configurável, inicializado em `0,0000033 ETH/CDX`. A recompra é opcional, paga apenas de um orçamento ETH alocado manualmente pela administração e não cria preço mínimo nem direito de resgate para holders. O preço inicial é 98% do TWAP de 30 minutos do pool Uniswap V3 CDX/WETH configurado; não há fallback se o pool ou histórico estiver indisponível.
- `depositEth` deposita ETH não alocado; a multisig administra orçamento com `allocateBuybackBudget`. `withdrawUnallocatedEth` só permite retirar ETH fora desse orçamento. Mint e staking não exigem colateral ETH; rewards ficam reservados contra o cap de supply. Pausa bloqueia venda primária e recompra, mas não transfers ERC-20 nem saques de staking maduros.
- Staking por 90, 180, 270 ou 365 dias. A APR é expressa em basis points (`600 = 6%`, faixa configurável de 4,2% a 10%) e fica fixada no início do stake. O contrato reserva reward no cap; sem capacidade suficiente, o stake é recusado. Principal e reward reservado permanecem sacáveis após a maturidade, inclusive durante pausa.
- Pausa administrativa bloqueia mint, compra/venda de CDX, novos stakes e listagens/compras de NFT. Transfers ERC-20, cancelamento de listagens e saques maduros continuam disponíveis.
- Marketplace NFT separado e upgradeable: escrow, preço positivo definido pelo vendedor, pagamento em CDX, taxa de 0,9% para o fee collector e cancelamento disponível ao vendedor durante pausa. A taxa é arredondada para baixo em unidades mínimas de CDX.
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
CDX_FEE_COLLECTOR_ADDRESS=0x... # opcional; padrão: CDX_ADMIN_ADDRESS
NAME_TOKEN=CaDuCoinX
SYMBOL=CDX
UNISWAP_V3_FACTORY_ADDRESS=0x... # factory V3 oficial/verificada da rede
```

`CDX_ADMIN_ADDRESS` recebe o controle administrativo do proxy. Não registre valores secretos no repositório. O script verifica o chain ID antes de enviar transações e transfere o ownership do GameToken ao proxy CDX.

`CDX_FEE_COLLECTOR_ADDRESS` recebe as taxas do marketplace; se omitido, usa `CDX_ADMIN_ADDRESS`.

`UNISWAP_V3_FACTORY_ADDRESS` precisa ser a factory Uniswap V3 correta para a Optimism Sepolia e ter código implantado. O deploy cria o adaptador TWAP, mas não configura nem ativa recompra. Antes de habilitá-la, a multisig deve validar pool CDX/WETH, observações cobrindo 30 minutos e liquidez mínima; a disponibilidade de pool/histórico na testnet precisa ser verificada. As compras primárias não alocam automaticamente seu ETH para recompra.

Para deploy manual, execute `npm run deploy:testnet`. O script implanta o `GameToken`, o proxy CDX e o proxy do marketplace NFT. O workflow compila, executa testes e verifica advisories altos/críticos antes do deploy. O job exige `workflow_dispatch`, execução na branch `main`, confirmação explícita e aprovação do ambiente protegido. Não existe job de deploy automático em push ou PR.

## Upgradeability e segurança

O CDX usa proxy UUPS validado pelo plugin OpenZeppelin; a implementação bloqueia inicialização direta. Alterações de storage exigem revisão e testes de upgrade antes de qualquer contrato ser publicado.

Este repositório não é uma auditoria de segurança. Não use fundos reais nem trate APR, marketplace ou governança como auditados. Consulte [ROADMAP.md](ROADMAP.md) para riscos conhecidos, validações e backlog.
