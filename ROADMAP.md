# CaDuCoinX — diagnóstico e roadmap

**Estado atual:** 33 testes Hardhat passam após integrar recompra limitada por TWAP, marketplace NFT e mitigação dos achados desta revisão. `npm audit --audit-level=high` não reporta advisories altos/críticos; 43 avisos baixos/moderados permanecem (13 baixos, 30 moderados). Consulte a seção 13 para o estado corrente.
**Regra de release:** nenhum deploy de produção está autorizado por este documento.

**Nota de leitura:** as seções 1–10 registram o diagnóstico e o plano anteriores às correções; a seção 13 é a fonte para o estado e backlog atuais. As seções 11–12 também são registros históricos dos ciclos anteriores.

## 1. Resumo executivo

O projeto contém CDX ERC-20 upgradeable com cap de 1 bilhão, venda primária em ETH, recompra opcional a partir de orçamento multisig e cotação TWAP, staking com APR fixada e rewards reservados, níveis `GameToken` e marketplace NFT UUPS separado com fee de 0,9%. Mint e staking não exigem colateral ETH; `purchaseItem` está desabilitado até implementar entrega/liquidação. `npm ci`, compilação limpa de 60 fontes e 33 testes passam. A auditoria npm não mostra advisories altos/críticos, mas mantém 43 avisos transitivos baixos/moderados.

O projeto não está pronto para deploy de ativos reais: recompra depende de pool e parâmetros operacionais ainda não validados em testnet, `purchaseItem` está desabilitado até implementar settlement, e não houve auditoria formal ou implantação.

## 2. Diagnóstico do projeto

### Estrutura e capacidades encontradas no diagnóstico inicial

- `contracts/CaDuCoinXToken.sol`: ERC-20 upgradeable com limite de emissão, mint/burn de owner, staking por quatro durações, recompensas emitidas no saque, pausa herdada, níveis delegados a `GameToken` e compras de itens/NFTs.
- `contracts/GameToken.sol`: armazenamento de nível por endereço, com inicialização e controle de owner.
- `contracts/CaDuCoinXTokenProxy.sol`: wrapper de `ERC1967Proxy`; a implementação usa `UUPSUpgradeable` e restringe autorização de upgrade ao owner.
- `scripts/deploy.js`: implanta GameToken, lógica e proxy; exige endereço e metadados, mas não inicializa GameToken no caminho de deploy observado.
- `test/`: três arquivos com nove casos declarados, cobrindo inicialização/mint, armazenamento de stakes e níveis. Não há cobertura observada de saque/recompensa, pausabilidade, limite de emissão, inicialização hostil ou upgrade. `package.json` aponta `npm test` para Mocha; os casos importam o runtime Hardhat, então o comando de teste correto também precisa ser confirmado.
- `.github/workflows/main.yml`: roda no push para `main`, usa `npm install`, reinstala o plugin de upgrades alterando dependências durante o job e tenta deploy na Sepolia. Não há etapa de teste ou compilação antes do deploy.
- `README.md`: descreve Optimism como alvo e lista Sepolia para deploy; cita chain ID 69 e um roadmap trimestral aspiracional. Essas informações não demonstram que houve deploy ou que o comportamento foi validado.

### Bloqueio de validação

O `npm ci` executado falhou porque `@ensdomains/ens-contracts@1.2.2` referencia `@ensdomains/buffer@^0.1.1` e o registry respondeu 404 para `0.1.1`. O pacote ENS não aparece como import direto no código do projeto, mas está declarado como dependência. A falha precisa ser resolvida sem desativar checksum/TLS e sem alterar versões às cegas. Por isso, instalação reproduzível, compilação e testes permanecem **não validados**.

### Riscos técnicos observados ou a confirmar

- **Escala da recompensa:** comentários descrevem `600` como 6% e os limites como 4,2–10%, mas o cálculo divide por 1.000. Confirmar matematicamente e decidir a semântica antes de corrigir; a implementação atual pode calcular uma taxa dez vezes maior que a descrita.
- **Saque e teto de emissão:** `unstake` chama `mint` para a recompensa. Ao atingir `MAX_SUPPLY`, a chamada pode reverter junto com a transferência do principal, bloqueando o saque. O teto também precisa ser compatível com o modelo econômico.
- **GameToken no deploy:** o script implanta GameToken, mas não chama `initialize`. Além disso, `levelUp` aceita chamadas apenas do owner, enquanto CaDuCoinX delega a chamada ao contrato GameToken. O ownership precisa ser desenhado e testado no fluxo de deploy.
- **Pausa:** o token aplica `whenNotPaused` em operações selecionadas, mas não expõe funções para pausar/retomar. Definir operador, escopo e política de saque durante emergência.
- **Inicialização da implementação:** a lógica tem initializer público e não mostra bloqueio de inicialização no construtor. Revisar inicialização direta da implementação e validar o proxy com ferramenta compatível.
- **Upgradeability:** o código combina UUPS com um wrapper ERC-1967 manual. Ainda não há teste de upgrade, validação de layout ou política operacional de upgrade.
- **Administração:** owner único pode emitir, queimar saldo de terceiros, mudar taxa e autorizar upgrades. Definir governança, multisig e eventual timelock antes de valor real.
- **Marketplace:** compras acumulam tokens no contrato; não foi encontrado fluxo de retirada/liquidação para o vendedor ou administrador. A semântica de item/NFT, preço e custódia precisa ser especificada.
- **Rede:** Optimism mainnet, Optimism Sepolia e Ethereum Sepolia são redes distintas. A configuração atual contém apenas Sepolia; README e CI não provam alvo de deploy consistente.
- **CI/deploy:** deploy automático em push para `main` sem validação prévia aumenta risco operacional. Segredos de deploy não devem estar disponíveis em jobs de PR.

## 3. Estado atual vs. roadmap existente

| Tema | Evidência atual | Situação |
| --- | --- | --- |
| Token ERC-20 | Código upgradeable e testes básicos de inicialização/mint | Implementação inicial; execução não validada |
| Staking e recompensas | Entrada de stake e consulta de stakes; teste de unstake ausente | Parcial e com risco econômico/crítico de saque |
| Gamificação | Contador de nível e testes básicos | Básico; integração do deploy não validada |
| Marketplace/microtransações | Compra de item e NFT em contrato | Parcial; liquidação e requisitos de negócio indefinidos |
| Segurança/governança | Ownable, UUPS, guardas e limites no código | Controles incompletos; sem threat model, validação de upgrade ou auditoria observada |
| CI/CD | Workflow com deploy Sepolia em push para `main` | Não atende a uma sequência segura de PR, teste e deploy |
| Roadmap | Metas de Q1–Q4 no README | Não é plano executável: sem dependências, responsáveis ou aceite |

O roadmap trimestral deve ser substituído por fases curtas, dependências explícitas e gates de segurança. Listagens, parcerias, nova wallet e expansão multichain ficam fora do caminho crítico até validar contratos, economia e adoção inicial.

## 4. Plano de execução recomendado

| Fase | Objetivo e entregas | Dependências | Aceite | Prioridade / esforço |
| --- | --- | --- | --- | --- |
| 0 — Reprodutibilidade | Resolver o pacote ENS indisponível; alinhar instalação ao lockfile e Node 20 do CI; executar compilação e testes Hardhat; registrar comandos válidos. | Nenhuma | `npm ci` termina usando versões travadas; compilação e testes existentes executam e resultados ficam registrados. | P0 / M |
| 1 — Produto, economia e ameaça | Definir supply, recompensas/APR, funding, taxa fixada no stake, marketplace, papéis e rede de teste; threat model e invariantes. | Fase 0 para validar premissas técnicas | Decisões assinadas pelos responsáveis; fórmulas demonstradas com casos; nenhuma decisão econômica crítica implícita. | P0 / M |
| 2 — Arquitetura segura de contratos | Corrigir inicialização/ownership; tornar saque compatível com cap e pausa; definir padrão de proxy/UUPS, roles, marketplace e liquidação. | Fase 1 | Revisão de arquitetura aprovada; fluxos privilegiados, de emergência e de upgrade documentados; sem risco crítico aberto sem mitigação. | P0 / G |
| 3 — Implementação e testes | Implementar mudanças aprovadas; adicionar unitários, integração, invariantes e compatibilidade de upgrade. | Fases 1–2 | Suítes passam; invariantes de supply, staking e autorização cobertas; upgrade de teste preserva estado. | P0 / G |
| 4 — CI e operação | Separar validação de PR de deploy; usar instalação congelada; proteger segredos; criar deploy de testnet com gate, verificação e registro de endereços. | Fases 0 e 3 | PR não acessa segredos de deploy; compilação/testes bloqueiam merge; deploy testnet exige aprovação e registra chain ID/endereços. | P1 / M |
| 5 — Revisão independente e testnet | Revisão de segurança independente, reteste dos achados, deploy na testnet escolhida e monitoramento operacional. | Fases 1–4 | Achados críticos/altos resolvidos ou formalmente bloqueiam release; testes em testnet e runbook concluídos. | P1 / G |
| 6 — Gate de produção | Decidir se há produto, governança, liquidez e operação suficientes para mainnet; preparar rollout controlado. | Fase 5 e auditoria/revisão independente | Aprovação explícita, monitoramento e resposta a incidentes prontos, sem achados bloqueadores. Não é compromisso de lançamento. | P2 / G |

Esforço relativo: **P** pequeno, **M** médio, **G** grande. P0 bloqueia avanço seguro; P1 vem após o caminho crítico; P2 depende de evidência de prontidão e decisão de negócio.

## 5. Backlog priorizado

| ID | Tarefa | Prioridade / esforço | Dependências | Impacto | Critério de conclusão |
| --- | --- | --- | --- | --- | --- |
| B0.1 | Diagnosticar e corrigir a dependência ENS/lockfile sem substituir artefatos sem integridade verificável | P0 / M | Nenhuma | Bloqueia setup e validação | `npm ci` reproduzível com lockfile aprovado e versão suportada; nenhuma verificação desativada |
| B0.2 | Fixar runtime e comandos de compilação/teste, alinhando scripts e CI | P0 / P | B0.1 | Bloqueia feedback confiável | Node suportado documentado; instalação, compile e teste passam local/CI; contagem de testes não é zero |
| B0.3 | Definir tokenomics, fórmula, funding, cap e política de taxa após o stake | P0 / M | B0.2 | Evita rendimento inesperado e saque bloqueado | Documento aprovado com fórmulas, exemplos e invariantes econômicos |
| B0.4 | Definir rede de teste, governança administrativa e threat model | P0 / M | B0.2 | Evita privilégio/rede incorretos | Chain ID, papéis, ativos, trust assumptions e ameaças documentados e aprovados |
| B0.5 | Corrigir e testar inicialização, ownership de GameToken, pausabilidade e saque sob cap | P0 / G | B0.3–B0.4 | Evita controle perdido, emissão indevida e fundos presos | Testes cobrem deploy completo, inicialização hostil, pausa/retomada e saque mesmo no limite de emissão |
| B0.6 | Validar padrão UUPS/proxy e armazenamento com fluxo de upgrade | P0 / G | B0.4–B0.5 | Evita takeover ou corrupção de storage | Implementação bloqueada contra inicialização direta; upgrade autorizado testado; layout validado |
| B1.1 | Adicionar testes de limites, autorização, staking/recompensa, marketplace e invariantes | P1 / G | B0.3–B0.6 | Reduz regressões e falhas de fundos | Casos de sucesso/falha e propriedades de supply, saldo e stake executam automaticamente |
| B1.2 | Reestruturar CI: checks em PR, instalação imutável, sem deploy automático em push | P1 / M | B0.1–B0.2 | Reduz risco de release | PR executa compile/teste; nenhum deploy roda sem evento e aprovação explícitos |
| B1.3 | Implementar fluxo de deploy de testnet com validação de configuração e verificação | P1 / M | B0.4, B0.6, B1.2 | Torna testnet auditável | Falha antes de transação se configuração/endereço/chain ID divergirem; endereços e txs registrados |
| B1.4 | Revisão independente de segurança e correção/reteste dos achados | P1 / G | B1.1–B1.3 | Reduz risco residual | Relatório com severidade/evidência; nenhum crítico/alto aberto para o gate definido |
| B2.1 | Preparar monitoramento, runbook de incidentes e gate de produção | P2 / G | B1.3–B1.4 | Operação responsável | Alertas, responsáveis, rollback/pausa e aprovação de release exercitados em ensaio |

## 6. Riscos e mitigação

| Risco | Severidade inicial | Mitigação |
| --- | --- | --- |
| Recompensa 10x maior que a descrição ou taxa alterável após stake | Crítica | Aprovar fórmula e fixação da taxa no início; testar valores de 90/180/270/365 dias e limite máximo. |
| Teto de supply reverte `unstake` e prende principal | Crítica | Separar principal de recompensa; definir reserva/funding ou mecanismo que nunca condicione a devolução do principal a mint bem-sucedido. |
| GameToken não inicializado/ownership incompatível | Alta | Definir proprietário correto no deploy, inicializar exatamente uma vez e testar chamadas integradas. |
| Implementação inicializável diretamente | Alta | Bloquear initializer da implementação e validar implantação do proxy e autorização de upgrade. |
| Pausa sem operador ou política de saída | Alta | Definir papel de pauser e quais operações permanecem disponíveis durante emergência. |
| Owner único com poderes amplos | Alta | Usar multisig e, quando aplicável, timelock; minimizar e documentar privilégios. |
| Setup não reproduzível por dependência indisponível | Alta | Resolver origem/versão com integridade; usar lockfile e `npm ci`; manter dependências auditáveis. |
| CI pode publicar deploy sem checks ou aprovação | Alta | Mover deploy para workflow protegido/manual e separar ambientes/segredos. |
| Rede publicada/documentada diverge do deploy real | Alta | Verificar chain ID e endereço de RPC; nomear explicitamente Ethereum Sepolia, Optimism Sepolia e Optimism mainnet. |
| Marketplace retém tokens sem liquidação definida | Média/Alta | Especificar vendedor, custódia, retirada, cancelamento e falhas antes de habilitar compras. |

## 7. Decisões de arquitetura recomendadas

- Manter Solidity 0.8.x, Hardhat e bibliotecas OpenZeppelin com versões travadas e compatíveis; nenhuma atualização de major sem testes de regressão e upgrade.
- Tratar UUPS como padrão somente se a equipe validar chamadas de upgrade, storage layout, implementação bloqueada e governança. Usar validações do plugin OpenZeppelin no deploy e upgrades; remover ambiguidade do wrapper manual se a ferramenta escolhida cobrir o fluxo.
- Separar contrato de token, staking e gamificação se isso reduzir privilégios e acoplamento; não adicionar marketplace ou gamificação on-chain sem necessidade de produto demonstrada.
- Devolver sempre principal de staking independentemente da disponibilidade de rewards; rewards devem obedecer a funding/cap explicitamente aprovado.
- Administrar upgrade, mint e taxa por multisig; definir pausa de emergência com escape de saque, sujeito a threat model e testes.
- Alvo de teste precisa ser decisão explícita: Ethereum Sepolia não é Optimism Sepolia. Produção Optimism mainnet deve usar chain ID 10; Optimism Sepolia usa 11155420; Ethereum Sepolia usa 11155111. Confirmar RPC/chain ID em execução antes de qualquer deploy.

## 8. Estratégia de testes e segurança

1. **Base reproduzível:** `npm ci`, compilação Hardhat e execução de todos os testes existentes no runtime documentado.
2. **Unitários:** limites de mint/supply, papéis, inicializador, endereços inválidos, taxas mín/máx, durações válidas, pausabilidade e comportamento ERC-20.
3. **Staking:** stake zero/sem saldo/duração inválida; maturidade; reward em cada prazo; taxa fixada; saque repetido/índice inválido; cap atingido; principal sempre sacável; reentrância.
4. **Integração:** deploy completo com GameToken inicializado e ownership coerente; compras/marketplace; eventos e estados após cada transação.
5. **Invariantes e fuzz:** supply nunca acima do cap; stake contabilizado corresponde aos fundos sob custódia; nenhum usuário saca principal/reward duas vezes; operações privilegiadas falham para não autorizados.
6. **Upgrade:** autorização, implementação não inicializável diretamente, armazenamento e saldos preservados após upgrade; falha explícita para implementação incompatível.
7. **Segurança e pipeline:** análise estática/fuzzing adequados à stack, revisão independente, dependências verificadas, PR sem secrets, deploy protegido e reteste de achados.

Testes com resultados não obtidos permanecem **não executados**; nenhum teste/auditoria é presumido concluído por existir configuração ou código.

## 9. Próximos passos imediatos

1. Resolver B0.1 e registrar a cadeia da dependência indisponível e a fonte confiável da correção.
2. Executar instalação, compilação e testes com Node 20 e corrigir divergências entre `npm test` e o runner Hardhat.
3. Antes de mudar contratos, aprovar fórmula de rewards, fonte de funding, comportamento do cap, ownership de GameToken e política de pausa.
4. Aprovar rede de teste e threat model; então abrir tarefas B0.5 e B0.6 como mudanças de código revisadas separadamente.
5. Atualizar status deste roadmap com evidência ao fim do ciclo; não avançar para deploy se P0 estiver aberto.

## 10. Checklist do agente principal e especialistas

### Agente principal

- [ ] Confirmar objetivo, escopo e decisões de produto pendentes.
- [ ] Checar evidência e status de cada fase; atualizar dependências e prioridades.
- [ ] Coordenar frentes com escopo e entregáveis claros; integrar e resolver divergências.
- [ ] Manter bloqueios ambientais separados de defeitos confirmados.
- [ ] Não autorizar produção; exigir gate explícito e revisão independente.

### Especialistas

- [ ] **Arquitetura/tokenomics:** fórmula, supply, rewards, funding, papéis e rede aprovados.
- [ ] **Contratos:** inicialização, autorização, pausa, staking, saques e upgrade validados.
- [ ] **Testes:** cenários de sucesso/falha e invariantes executados; falhas classificadas.
- [ ] **Segurança:** threat model e achados independentes registrados e retestados.
- [ ] **DevOps:** instalação congelada, PR checks, secrets protegidos e deploy de teste com gate.
- [ ] **Documentação:** claims e rede correspondem ao código/deploy verificado; status distinguem concluído e planejado.

## 11. Revisão técnica inicial — 2026-10-31 (histórico, substituída pela seção 12)

### Validações executadas

| Verificação | Resultado | Evidência / limite |
| --- | --- | --- |
| Inventário de contratos, testes, configuração, script de deploy, CI, lockfile e README | Concluído — revisão estática | Arquivos do checkout inspecionados; nenhum deploy executado. |
| `npm ci --cache /tmp/caducoinx-npm-cache` | Bloqueado | Exit 1: registry retorna 404 para `@ensdomains/buffer@0.1.1`, exigido por `@ensdomains/ens-contracts@1.2.2`. |
| `npm audit --package-lock-only --json` | Falhou com advisories | Exit 1; grafo do lockfile: 126 advisories (26 críticas, 37 altas, 60 moderadas, 3 baixas). Há advisories de malware para `@ensdomains/buffer` e `@ensdomains/ens-contracts`. A contagem inclui dependências transitivas e não equivale a 126 falhas exploráveis no contrato. |
| Compilação e testes Hardhat | Não executados | `npm ci` não concluiu; checkout sem `node_modules`. Os nove casos declarados nos três arquivos de teste não foram executados. |
| Analisadores estáticos locais (`slither`, `solhint`, `solc`, `forge`, `semgrep`) | Não disponíveis no PATH | Nenhuma análise automatizada de Solidity foi executada. |

O ambiente reportou Node 24.19.0, enquanto o workflow fixa Node 20. A execução reproduzível deve ser repetida em Node 20 após resolver o bloqueio de dependências. O relatório do npm audit descreve o lockfile consultado; deve ser reexecutado após qualquer atualização para confirmar a situação corrente.

### Achados priorizados

Severidade é uma avaliação estática inicial, não um resultado de auditoria formal. **Confiança alta** indica que a condição pode ser concluída diretamente do código; impacto de negócio ainda pode depender de decisões de produto.

| ID | Severidade / confiança | Achado e evidência | Impacto | Ação e critério de reteste |
| --- | --- | --- | --- | --- |
| SEC-01 | **Crítica / alta** | `purchaseNFT` aceita `price` fornecido pelo caller, não valida preço/listagem e transfere qualquer NFT cujo owner seja o contrato (`contracts/CaDuCoinXToken.sol:115-126`). Preço zero passa pela checagem de saldo. | Qualquer pessoa pode retirar sem pagamento um NFT mantido pelo contrato. | Usar listagem persistida e preço definido pelo vendedor/administrador, consumir a listagem uma única vez e validar custódia. Testar compra grátis, preço adulterado, NFT inexistente, replay e tentativa por token ERC-721 malicioso; nenhuma retirada sem preço autorizado. |
| SEC-02 | **Crítica / alta** | Comentários indicam `600 = 6%`, mas o cálculo divide por 1.000 (`contracts/CaDuCoinXToken.sol:35-38,152-155`). | Taxa anual efetiva é 60% em vez de 6%; os limites declarados de 4,2–10% viram 42–100%, se essa era a semântica pretendida. | Aprovar unidade/fórmula econômica antes de mudar valores. Testar APR nos quatro prazos, limites mínimo/máximo e arredondamento contra exemplos aprovados. |
| SEC-03 | **Crítica / alta** | `unstake` transfere principal e depois chama `mint`; `mint` reverte quando `totalSupply + reward > MAX_SUPPLY` (`contracts/CaDuCoinXToken.sol:76-79,158-180`). | A transação inteira reverte, inclusive a devolução do principal, podendo prender stakes maduros ao atingir o cap. | Fazer a devolução do principal independente de emissão de reward; definir reserva/funding e tratamento de rewards sem fundos. Testar saque com cap livre, exatamente no cap e sem capacidade de reward; principal sempre recuperável. |
| SEC-04 | **Crítica de supply chain / alta** | A dependência direta `@ensdomains/ens-contracts@1.2.2` está no manifesto, mas não há import ENS no código. npm audit a associa a advisory de malware; sua dependência `@ensdomains/buffer@0.1.1` também é marcada como malware e o tarball responde 404. (`package.json:16-24`, lockfile). | Instalar/deployar com esse grafo não é aceitável sem resolver a dependência; advisories críticos adicionais no toolchain aumentam risco de desenvolvimento/CI. | Remover a dependência não utilizada ou substituí-la somente após confirmar necessidade e origem suportada; regenerar lockfile em mudança revisada. Exigir `npm ci`, `npm audit` revisado e documentação das exceções antes de voltar a instalar/deployar. |
| SEC-05 | **Alta / alta** | O script implanta GameToken mas não chama `initialize`; qualquer endereço pode inicializar `GameToken.initialize` (`scripts/deploy.js:4-10,41-54`; `contracts/GameToken.sol:16-24`). | Terceiro pode assumir ownership primeiro e controlar níveis; a chamada delegada pelo token também falhará porque o GameToken não reconhece o token como owner. | Inicializar atomicamente ou transferir ownership ao endereço de controle correto antes de expor o contrato. Testar deploy completo, tentativa de front-run e chamada `levelUp` pelo token. |
| SEC-06 | **Alta / alta** | O workflow executa deploy em todo push para `main`, não roda compilação/testes, usa `npm install` e reinstala plugin alterando dependências (`.github/workflows/main.yml:3-43`). | Um merge pode disparar transações sem validação prévia e com resolução de dependências diferente do lockfile. | Checks em PR com `npm ci`, compile e testes; deploy isolado em workflow protegido/manual com aprovação, configuração de rede validada e sem secrets em PR. Testar que PR nunca alcança job de deploy. |
| SEC-07 | **Alta / média** | O owner pode queimar saldo de qualquer endereço sem autorização do holder (`contracts/CaDuCoinXToken.sol:82-85`) e também controlar mint, taxa e upgrades (`:67-79`). | Poder de confisco e concentração administrativa; pode ser intenção de produto, mas não está explicado como política de governança. | Decidir explicitamente se burn confiscatório é requisito; caso não seja, limitar ao próprio holder ou exigir allowance. Colocar poderes privilegiados sob multisig/timelock. Testar todos os papéis e registrar política pública. |
| SEC-08 | **Alta / alta** | Contrato usa `PausableUpgradeable` e vários `whenNotPaused`, mas não expõe função para pausar/retomar; transfers ERC-20 normais não são limitadas por `whenNotPaused` (`contracts/CaDuCoinXToken.sol:13,55-65,70-104,129-160`). | Não há resposta de emergência utilizável; adicionar apenas uma função de pause sem definir comportamento de transfer/saque seria insuficiente. | Definir papel de pauser e operações congeladas, preservando saída segura de staking. Testar pause, unpause e comportamento de transferências e saques conforme política aprovada. |
| SEC-09 | **Alta / média** | `initialize` aceita `_gameToken` sem validar endereço/código (`contracts/CaDuCoinXToken.sol:55-64`); `getPlayerData` e `levelUp` dependem desse endereço. | Zero/EOA/contrato errado pode quebrar gamificação ou prender deploy ao endereço incorreto. | Validar endereço e interface/código conforme desenho; em deploy, confirmar chain ID, owner e endereço vinculado. Testar zero, EOA e contrato incompatível. |
| SEC-10 | **Média / média** | `purchaseNFT` chama contrato ERC-721 arbitrário por `transferFrom` sem `nonReentrant` (`contracts/CaDuCoinXToken.sol:115-126`). | Há uma chamada externa não confiável e nenhum teste para contrato NFT malicioso; explorabilidade/impacto de reentrância precisam de demonstração. | Limitar tokens aceitos/listados, proteger estado e chamada externa, preferir fluxo checks-effects-interactions. Testar ERC-721 adversarial e confirmar que saldo/listagem/NFT não podem ser usados duas vezes. |
| SEC-11 | **Média / alta** | O `npm audit` aponta advisories no lockfile para `hardhat` (incluindo crítico) e diversos pacotes diretos/transitivos: ethers, Waffle, upgrades plugin, Mocha, solc e OpenZeppelin; Contracts 5.2.0 aparece no intervalo de um advisory moderado (>=5.2.0 <5.4.0). | Risco de cadeia de ferramentas e desenvolvimento; advisory de biblioteca não prova que o código vulnerável é alcançável pelo contrato. | Gerar matriz de dependências direta/transitiva e atualizar em lotes compatíveis; revisar changelogs e advisories; manter lockfile; executar testes, auditoria novamente e validar upgrade/layout após OpenZeppelin. Não usar `npm audit fix --force` sem revisão. |
| SEC-12 | **Média / alta** | README promete achievements, missões, badges, leaderboard, cashback, pausa e rendimento 4–10%; os contratos encontrados só mantêm nível e não implementam vários desses recursos. Também declara Optimism chain ID 69, enquanto Hardhat/CI configuram Ethereum Sepolia 11155111 (`README.md:49-57,90-118`; `hardhat.config.cjs:16-21`). | Usuários e operadores podem interpretar incorretamente recursos, rendimento, governança e rede de destino. | Atualizar claims após decisões e deploy verificável; identificar Ethereum Sepolia, Optimism Sepolia (11155420) e Optimism mainnet (10) sem misturar ambientes. Validar chain ID e endereços no deploy. |
| SEC-13 | **Média / média** | `purchaseItem` transfere CDX ao contrato sem função de retirada/liquidação observada (`contracts/CaDuCoinXToken.sol:97-112`). `purchaseNFT` permite que qualquer contrato NFT seja usado e o caller define preço. | Tokens de compras podem ficar retidos e a semântica de marketplace/custódia está incompleta. | Definir vendedor, destinatário, custódia, cancelamento/reembolso e retirada; cobrir estados e eventos antes de habilitar marketplace. |
| SEC-14 | **Baixa / média** | Implementação upgradeable não mostra construtor com `_disableInitializers` (`contracts/CaDuCoinXToken.sol:13,54-65`). | A implementação pode ser inicializada isoladamente; não há evidência de que isso controle o storage do proxy, mas amplia superfície operacional e não segue a proteção recomendada para implementações UUPS. | Bloquear inicialização da implementação e validar deploy/upgrade com plugin OpenZeppelin, incluindo tentativa de inicialização direta e preservação de estado do proxy. |

### Status atualizado do backlog

- **B0.1 — bloqueado:** `npm ci` falha no pacote ENS; npm audit aponta advisory de malware na dependência direta e no pacote transitivo. Não instalar ou publicar este grafo até corrigir a origem/dependência com revisão.
- **B0.2 — bloqueado:** compile e testes não executados por falta de instalação; o ambiente usa Node 24.19.0, mas CI declara Node 20; script `npm test` chama Mocha, enquanto os testes carregam `hardhat` e devem ser validados pelo runner correto.
- **B0.3/B0.4 — pendentes:** fórmula de rewards/cap, burn confiscatório, rede, papéis e threat model precisam de decisões dos responsáveis.
- **B0.5 — prioridade máxima após decisões:** incluir SEC-01 a SEC-05 e SEC-08 a SEC-10; impedir que marketplace permita retirada sem pagamento.
- **B0.6 — pendente e bloqueador de deploy:** revisar inicialização UUPS e teste de storage/upgrade; SEC-14 é hardening, não evidência de takeover do proxy.
- **B1.1/B1.2 — bloqueadores de release:** cobrir cada cenário de SEC-01 a SEC-14 e remover deploy em push sem validações.
- **B1.3/B1.4/B2.1 — não iniciados:** testnet, revisão independente e gate de produção dependem de concluir P0/P1.

### Próximos passos desta revisão

1. Bloquear instalação/deploy da dependência ENS atual; identificar por que foi adicionada e removê-la se realmente não for usada, revisando lockfile e relatório npm audit.
2. Corrigir o desenho de listagem/preço do NFT antes de qualquer uso com ativos em custódia; cobrir compra a preço zero e preço adulterado.
3. Aprovar economia de staking e garantir que reward/cap nunca impeça a devolução do principal.
4. Corrigir deploy integrado de GameToken, definir ownership e rede; exigir chain ID esperado e addresses validados antes de transações.
5. Reestruturar CI para checks em PR e deploy isolado protegido; depois reexecutar compilação, testes, npm audit e análise estática.

**Conclusão do ciclo:** revisão estática concluída; instalação bloqueada, auditoria de dependências reportou advisories, compilação/testes e análise formal de contratos não executados. Não considerar o projeto pronto para deploy com ativos até fechar os achados críticos e repetir as validações.

## 12. Correções de segurança e revalidação — 2026-10-31 (status anterior, atualizado pela seção 13)

Esta seção registra a implementação posterior aos achados da seção 11. Os status antigos são mantidos como histórico; para o estado corrente, prevalecem esta seção e o código atual.

### Status das correções

| Achado | Status | Implementação / evidência | Reteste |
| --- | --- | --- | --- |
| SEC-01 — retirada de NFT sem preço persistido | Corrigido | `listNFT`, `buyNFT` e `cancelNFTListing` usam escrow e preço positivo registrado pelo vendedor; estado é consumido antes das chamadas externas; `nonReentrant`; transferências ERC-721 não associadas a listagem são rejeitadas. | Coberto por testes de preço, listagem, cancelamento, transferência não solicitada e reentrância. |
| SEC-02 — escala de reward | Corrigido conforme premissa de produto | APR em basis points, `600 = 6%`, anualização por 365 dias. | Testes para quatro prazos e fixação da taxa no início do stake. |
| SEC-03 — saque bloqueado pelo cap / onlyOwner | Corrigido | Reward é reservado no stake; mint administrativo respeita `reservedRewards`; saque maduro remove reserva e emite reward internamente, sem `onlyOwner` nem bloqueio por pausa. | Testes de reserva, recusa de novos stakes sem capacidade e claim por não owner durante pausa. |
| SEC-04/SEC-11 — ENS e advisories críticos/altos | Corrigido em parte | Dependências ENS/Waffle removidas; Hardhat 2, Toolbox, ethers 6, OpenZeppelin 5.4 e Upgrades plugin travados no lockfile; overrides revisados. | `npm ci` passou. `npm audit --audit-level=high` passou com zero alto/crítico; ainda há 40 advisories transitivos (13 baixos, 27 moderados), alguns sem correção disponível. Não alegar ausência total de advisories. |
| SEC-05/SEC-09 — GameToken e inicialização | Corrigido | `GameToken` usa ownership no construtor; deploy transfere ownership ao proxy; inicializador CDX valida endereço e código de GameToken; script valida chain ID 11155420 antes do deploy. | Testes locais de ownership, integração e bloqueio de inicialização direta. O script não foi executado contra rede. |
| SEC-06 — CI/deploy | Corrigido no repositório | PR/push executam `npm ci`, audit por nível alto, compile e testes; deploy separado em `workflow_dispatch`, branch main, ambiente protegido e secrets só no job de deploy. | Revisão do YAML; execução remota do GitHub Actions ainda pendente. |
| SEC-07 — burn confiscatório / poderes | Corrigido em parte | `burn(uint256)` queima apenas saldo do caller; owner ainda controla mint, taxa, pausa e upgrade. README orienta multisig em produção. | Teste de burn próprio e de saldo insuficiente; multisig não é imposta pelo contrato e deve ser definida no deployment. |
| SEC-08 — pausa e saída | Corrigido | Owner pode pausar/retomar; pausa bloqueia mint, stakes novos e operações de marketplace, preservando transfers, cancelamento e saques maduros. | Testes de pausa e saque de reward durante pausa. |
| SEC-10 — reentrância de NFT | Corrigido para fluxo de listagem/compra | `nonReentrant`, escrow, validação de custódia e consumo de listagem antes de interações externas. | Teste com receiver ERC-721 adversarial. |
| SEC-12 — documentação e rede | Corrigido | README limita claims aos recursos encontrados e distingue Optimism Sepolia, Optimism mainnet e Ethereum Sepolia. | Revisão documental; nenhum endereço de deploy é alegado. |
| SEC-13 — `purchaseItem` sem liquidação | Aberto e explicitamente limitado | A função permanece experimental; valores recebidos ficam no contrato, sem retirada/liquidação. README adverte para não usar. | Remover/desabilitar a função ou implementar settlement/refund com testes antes de disponibilizá-la. |
| SEC-14 — inicialização e upgrade UUPS | Corrigido | Implementação usa `_disableInitializers`; implantação/upgrade usa plugin OpenZeppelin. | Testes de inicialização direta e upgrade que preserva saldo, owner e GameToken. |

### Validação executada

| Check | Resultado | Evidência / limite |
| --- | --- | --- |
| `npm ci` | Passou | Árvore instalada a partir do lockfile sem a dependência ENS anteriormente indisponível. |
| `npm run compile` | Passou | 18 fontes Solidity compiladas com `solc 0.8.28`, EVM Cancun; override usa o compilador npm travado no lockfile. |
| `npm test` | Passou | 19 testes Hardhat: token/administração, marketplace NFT, staking, GameToken, inicialização e upgrade. |
| `npm audit --audit-level=high` | Passou no limite definido | Zero advisories altos/críticos; 40 advisories permanecem (13 baixos, 27 moderados), principalmente dependências transitivas do toolchain. Um `npm audit` sem limite ainda retorna exit code 1. |
| Workflow remoto, análise formal, testnet | Não executados | Nenhum workflow remoto, auditoria independente ou deploy foi realizado neste ciclo. |

### Backlog reordenado

1. **P0 — resolver SEC-13:** desabilitar `purchaseItem` até definir liquidação/reembolso, ou implementar fluxo completo com autorização, destinatário, eventos e testes.
2. **P0 — fechar o risco de advisories moderados:** revisar grafo transitivo e atualizar ou documentar exceções com justificativa; monitorar mudança do registry e do npm audit. O gate atual bloqueia altos/críticos, não todos os moderados.
3. **P1 — validar execução de CI:** abrir PR e confirmar jobs, permissões e ausência de secrets no job de validação; testar deploy manual com RPC/chain ID errados sem enviar transação.
4. **P1 — revisão independente:** análise de contrato e threat model cobrindo marketplace ERC-721 hostil, invariantes do cap/reserva e layout UUPS.
5. **P1 — decisão operacional:** definir multisig/admin para testnet e produção, política de upgrade/pausa e monitoramento; manter mainnet bloqueada até aprovação de auditoria e checklist de release.
6. **P2 — marketplace de itens:** implementar ou retirar a interface experimental `purchaseItem`; validar impacto em integrações antes de release.

**Gate de deploy:** o deploy de testnet segue manual e não foi executado. Não considerar pronto para fundos reais enquanto SEC-13, advisories moderados sem disposição documentada, revisão independente e governança operacional permanecerem sem fechamento.

## 13. Recompra opcional com orçamento limitado — 2026-10-31

### Decisão de arquitetura e estado

- A venda primária permanece inicialmente em `0,0000033 ETH/CDX`; o cap é 1 bilhão e staking/GameToken continuam no escopo.
- O mint administrativo e os rewards de staking são limitados pelo cap; rewards são reservados no início do stake. Não existe colateral ETH integral para supply ou rewards.
- Recompra é opcional e não garante preço mínimo ou resgate. A administração transfere ETH para o contrato e aloca orçamento manualmente; a tesouraria só retira ETH não alocado. Vendas primárias não alocam orçamento automaticamente.
- A cotação paga 98% do TWAP de 30 minutos do pool Uniswap V3 CDX/WETH, não 98% do preço primário. O vendedor define `minEthOut`; CDX é queimado e ETH é transferido atomicamente dentro do orçamento disponível.
- Tanto a liquidez harmônica histórica quanto a liquidez ativa no tick atual precisam superar o limiar configurado. Isso reduz o risco de cotar contra pool sem liquidez ativa, mas não equivale a simular a profundidade exata para cada tamanho de venda.
- Sem factory, pool reconhecido, histórico de pelo menos 30 minutos ou liquidez harmônica mínima, ativação/cotação falha sem fallback. Buyback começa desativado; a administração deve validar endereço da factory/pool, observações e liquidez antes de ativar.
- Deploy de testnet implanta o adaptador oracle, mas não configura pool, não aloca orçamento e não ativa recompra. Factory da Optimism Sepolia deve ser fornecida por variável de ambiente e validada contra a rede antes do deploy.

### Reteste requerido

| Check | Estado | Critério |
| --- | --- | --- |
| Pool e TWAP | Validado localmente | Testes cobrem par/factory, cotação a 98% do TWAP, histórico insuficiente, liquidez mínima e `minEthOut`; disponibilidade real da testnet continua pendente. |
| Orçamento | Validado localmente | Testes provam limite, desalocação apenas com recompra desativada, retirada de ETH não alocado e rollback de burn/accounting quando pagamento falha. |
| Desalocação | Validado localmente | Com recompra desativada, multisig pode mover orçamento de volta à parcela não alocada e retirar ETH; valor acima do budget é rejeitado. |
| Liquidez do pool | Validado localmente | Buyback requer limiar tanto para média harmônica TWAP quanto para liquidez ativa atual; histórico alto com liquidez atual zero é rejeitado. O limiar não simula profundidade para o tamanho integral da ordem. |
| Compra de itens | Desabilitada até settlement | `purchaseItem` reverte sem mover CDX enquanto entrega e liquidação não estiverem implementadas; teste verifica saldo do usuário e contrato. |
| NFTs com admin privilegiado | Risco externo mitigado parcialmente | Se a coleção queimar ou retirar NFT do escrow, qualquer pessoa pode limpar listing obsoleta; o marketplace não recupera ativo queimado/transferido pelo contrato da coleção. |
| Cap e staking | Validado localmente | Suíte cobre cap, rewards reservados, mint sem colateral, quatro prazos e saque maduro durante pausa. |
| Upgrade/layout | Testes locais passaram | Teste de upgrade preserva stakes/reservas e estado de recompra; revisão final de layout antes de publicar continua necessária. |
| Dependências e checks | Validado localmente | Node 24: `npm ci` passou; compilação limpa passou (60 fontes); `npm test` passou (33 testes); `npm audit --audit-level=high` passou sem altos/críticos, com 43 avisos baixos/moderados (13 baixos, 30 moderados). |
| Testnet | Não executado | Confirmar factory oficial, suporte/histórico e liquidez do pool CDX/WETH na Optimism Sepolia. Não realizar deploy neste ciclo. |

### Limitações operacionais

- TWAP reduz dependência de preço spot, mas não elimina manipulação econômica em pools com liquidez baixa. Os limites de liquidez harmônica e ativa são parâmetros operacionais e requerem análise adequada para a escala e o tamanho de ordens CDX.
- TWAP não valida valor fundamental nem garante que o contrato tenha orçamento suficiente. `minEthOut` protege o vendedor contra cotação abaixo de sua expectativa; não limita risco de preço futuro ou de governança.
- Alterar pool ou limiar de liquidez requer recompra desativada. O owner pode desalocar budget apenas quando a recompra estiver desativada. Configuração/ativação/orçamento devem ficar sob multisig; manter recompra desativada até verificar contrato, pool, observações e fundos.
- Testes mockados validam a integração ABI e falhas esperadas, mas não provam a existência de histórico, profundidade ou liquidez adequada em Optimism Sepolia. Coleções ERC-721 com admin capaz de alterar custódia permanecem um risco externo; limpar listing obsoleta não recupera o NFT.
