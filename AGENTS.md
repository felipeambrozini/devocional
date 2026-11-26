# Instruções do projeto

Este arquivo é o espelho do [CLAUDE.md](CLAUDE.md) para o OpenCode e o Codex.
As regras são as mesmas. Só muda o jeito de chamar o que, no Claude Code, é
agente, plugin ou skill. Ao mudar uma regra no CLAUDE.md, mude aqui também.

- Sempre que implementar algo (feature, fix, refactor), após codificar, atualize
  a documentação relevante (README.md, PRODUCT.md, etc.) se a mudança afetar o
  que está documentado.
- Sempre que implementar algo, após codificar, rode
  `fvm flutter analyze && fvm flutter test` para verificar se está tudo ok.
- Feature flags são controladas no Firestore (`config/recursos`, ver
  [lib/dados/config_admin.dart](lib/dados/config_admin.dart)) — interruptores
  booleanos, mais os convidados do chat em `convidados/{email}` — lidas por
  [lib/dados/recursos.dart](lib/dados/recursos.dart) (conversas, planos
  personalizados, voz, etc.). O painel `/admin` (só web e só o dono) edita sem
  reimplantar. Use esse mecanismo em vez de reimplementar gating na mão. O
  passo a passo está no skill
  [.agents/skills/feature-flag-gate/SKILL.md](.agents/skills/feature-flag-gate/SKILL.md).
- O arquivo `.env.json` na raiz precisa existir localmente (chaves
  Firebase/Gemini) para rodar o app; não versionar o conteúdo dele.
- Versionamento (`version: X.Y.Z+N` em `pubspec.yaml`): o Android só atualiza
  por cima de um build com `+N` maior, sem precisar desinstalar, então todo bump
  soma 1 ao `+N`, que nunca volta atrás nem é zerado. Bug fix e refactor somam
  1 ao patch e ao `+N` (`1.15.0+34` → `1.15.1+35`). Funcionalidade nova soma 1
  à minor, zera o patch e soma 1 ao `+N` (`1.15.1+35` → `1.16.0+36`). Bumpe
  quando o push para `main` estiver prestes a acontecer. Ajuste de
  texto/documentação e iteração local não mexem na versão.
- Trabalhe sempre direto na branch `main`. Nunca crie branch nem worktree para
  implementar tarefas deste projeto — nada de isolamento por branch/worktree,
  mesmo quando um skill ou processo sugerir isso por padrão.
- O skill `diletta-fluxo` (GitFlow, Bitbucket, OpenSpec) não vale neste
  projeto: branch, commit e versão seguem as regras acima.
- Sempre que uma tela (`lib/telas/`) ou widget de UI (`lib/widgets/`) for criado
  ou alterado, após codificar, faça a revisão do `ui-reviewer` nos arquivos
  mudados e corrija os achados de gravidade alta antes de dar a tarefa por
  concluída. O roteiro da revisão está em
  [.claude/agents/ui-reviewer.md](.claude/agents/ui-reviewer.md): siga-o como
  subagente, se a ferramenta tiver, ou na própria sessão.
- Sempre que um texto visível ao usuário for criado ou alterado (strings de
  `lib/telas/` e `lib/widgets/`, textos de `lib/dados/` que vão para a tela,
  como o `boasVindas` das personas, e os metadados de `web/index.html` e
  `web/manifest.json`), após codificar, aplique o skill `stop-slop` nos textos
  mudados e reescreva o que cair nas regras dele antes de dar a tarefa por
  concluída. Ficam de fora os comentários e introduções de `assets/` e as
  instruções de sistema das personas. O skill fica em
  [.agents/skills/stop-slop/SKILL.md](.agents/skills/stop-slop/SKILL.md). Se
  ele não aparecer na lista, leia pelo caminho: num clone com
  `core.symlinks=false`, `.claude/skills` vira um arquivo de texto e os skills
  do projeto somem. No Windows, isso se resolve com o Modo de Desenvolvedor,
  `git config core.symlinks true` e um novo checkout de `.claude/skills`.
- Sempre que uma tela (`lib/telas/`) ou widget de UI (`lib/widgets/`) for criado
  ou alterado, após codificar, aplique o skill `unslop` (plugin
  `unslop@heydamir` do Claude Code) nos arquivos mudados, junto com o
  `ui-reviewer`. Fora do Claude Code, leia a lista de sinais direto da cópia
  instalada, em
  `~/.claude/plugins/marketplaces/heydamir/skills/unslop/references/signs.md`.
  Use só o modo polimento do skill: audite pela lista de sinais, corrija o que
  achar e leve ideias maiores para o relato como sugestão, sem os nove passes,
  sem nova direção, sem imagem gerada e sem vídeo. O [DESIGN.md](DESIGN.md) é a
  marca e vence onde os dois divergirem. Decisões já tomadas, que o unslop não
  deve reabrir:
  - Cinzel com os pesos do DESIGN.md (700 nos `display`, 600 nos títulos) e
    superfícies de pergaminho e couro, não cinza neutro;
  - a escala de `TabernaculoEspacamento`, com 6, 10, 14 e 18 (não é grade de
    4px);
  - a saudação "Bom dia, Nome" da aba Hoje e a voz das personas (o
    `boasVindas` e as instruções de sistema, inclusive o emoji do modelo de
    descrição do YouTube);
  - ponto final: avisos curtos, subtítulos curtos, estados vazios e erros de
    uma linha vão sem ponto; frases descritivas completas, passos de
    instrução, corpo de diálogo e parágrafos mantêm (PRODUCT.md, "Regras de
    texto do produto");
  - itálico em citações, títulos formais de livros e notas; referência da
    epígrafe em caixa-alta; os gradientes funcionais do filete, da alça de
    deslize e do esmaecimento no fim do texto.

## Revisões e testes

Os roteiros dos agentes do projeto ficam em `.claude/agents/*.md` e valem para
qualquer ferramenta. Fora do Claude Code, leia o arquivo e siga o roteiro como
subagente, se a ferramenta tiver, ou na própria sessão:

- [ui-reviewer](.claude/agents/ui-reviewer.md): acessibilidade de telas e
  widgets, após criar ou alterar UI;
- [security-rules-reviewer](.claude/agents/security-rules-reviewer.md):
  antes de deploy, sempre que `firestore.rules`, `storage.rules` ou
  `lib/dados/nuvem.dart` mudarem;
- [flutter-test-writer](.claude/agents/flutter-test-writer.md): testes para
  funcionalidade nova ou bug fix, nas convenções de `test/`.

No OpenCode, os três existem como subagentes em `.opencode/agents/`, gerados a
partir de `.claude/agents/` e com o modelo fixado no campo `model:`. Ao mudar
um roteiro em `.claude/agents/`, copie o corpo para o arquivo de mesmo nome em
`.opencode/agents/`. A pasta `.opencode/` fica fora do Git
(`.git/info/exclude`), então esses arquivos existem só nesta máquina.

A sessão principal planeja, decide o que delegar, junta os resultados e faz a
revisão final antes do push. Busca, leitura e mudança mecânica podem ir para um
modelo mais rápido (o `explore` usa o Nemotron 3.5 Lightning, definido em
`.opencode/opencode.json`); as revisões que barram qualidade (`ui-reviewer`,
`security-rules-reviewer`) não. Tarefa que cabe em poucas chamadas de
ferramenta a sessão principal faz sozinha, sem delegar: cada repasse perde
contexto.

## Ferramentas de Flutter

- Acessibilidade automática: ao criar ou alterar uma tela ou widget de UI,
  cubra-o com um teste de widget que use o `meetsGuideline` do
  `flutter_test` (`androidTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline`), nos dois temas. É o detector automático que o
  impeccable não tem para Flutter, e roda dentro do `fvm flutter test`. Hoje
  só `test/instalacao_test.dart` faz isso; use-o como modelo.
- Verificação em execução: o Flutter web desenha tudo num canvas, então o
  navegador não enxerga a árvore de widgets. Para conferir uma mudança com o
  app rodando (árvore de widgets, erros em tempo de execução, hot reload), use
  o servidor MCP do Dart (`dart mcp-server`), se a ferramenta tiver acesso a
  ele.

## Documentos de trabalho

Briefs, rascunhos e relatórios (brainstorm, rascunho, revisão, drift report)
ficam em `docs/designs`, e as especificações aprovadas também, em vez de soltos
na raiz do projeto.
