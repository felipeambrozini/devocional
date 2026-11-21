# Instruções do projeto

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
  reimplantar. Use esse mecanismo em vez de reimplementar gating na mão.
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
- Sempre que uma tela (`lib/telas/`) ou widget de UI (`lib/widgets/`) for criado
  ou alterado, após codificar, rode o agente `ui-reviewer` nos arquivos mudados
  e corrija os achados de gravidade alta antes de dar a tarefa por concluída.
- Sempre que um texto visível ao usuário for criado ou alterado (strings de
  `lib/telas/` e `lib/widgets/`, textos de `lib/dados/` que vão para a tela,
  como o `boasVindas` das personas, e os metadados de `web/index.html` e
  `web/manifest.json`), após codificar, aplique o skill `stop-slop` nos textos
  mudados e reescreva o que cair nas regras dele antes de dar a tarefa por
  concluída. Ficam de fora os comentários e introduções de `assets/` e as
  instruções de sistema das personas. Leia o skill pelo caminho,
  [.agents/skills/stop-slop/SKILL.md](.agents/skills/stop-slop/SKILL.md): no
  Windows sem link simbólico, `.claude/skills` vira um arquivo de texto e os
  skills do projeto não aparecem na lista.

## Orquestração por modelo

A sessão principal (Opus) orquestra: planeja, decide o que delegar, junta os
resultados e faz a revisão final antes do push. Ao delegar, escolha o modelo
pela tarefa:

- Haiku: busca e leitura (agente `Explore`, levantar onde algo é usado,
  resumir arquivos) e mudanças mecânicas sem decisão (renomear, ajustar
  import, aplicar textos já aprovados). Passe `model: haiku` na chamada
  quando o agente não tiver modelo fixo.
- Sonnet: implementação com escopo já definido, testes
  (`flutter-test-writer`) e as revisões obrigatórias (`ui-reviewer`,
  `security-rules-reviewer`). Revisor que barra qualidade não desce para
  Haiku.
- Opus: plano e arquitetura, mudanças que cruzam várias camadas, bugs sem
  causa clara e a revisão de acabamento (`impeccable-finish-reviewer`).

O modelo fixo de cada agente fica no campo `model:` de
`.claude/agents/*.md`. Tarefa que cabe em poucas chamadas de ferramenta a
sessão principal faz sozinha, sem delegar: cada repasse perde contexto.

## Ferramentas de Flutter

- Acessibilidade automática: ao criar ou alterar uma tela ou widget de UI,
  cubra-o com um teste de widget que use o `meetsGuideline` do
  `flutter_test` (`androidTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline`), nos dois temas. É o detector automático que o
  impeccable não tem para Flutter, e roda dentro do `fvm flutter test`. Use os
  skills `accessibility-as-code` e `widget-golden-and-a11y-testing` (plugin
  Flutter Skills) como guia. Hoje só `test/instalacao_test.dart` faz isso.
- Verificação em execução: o Flutter web desenha tudo num canvas, então o
  navegador não enxerga a árvore de widgets. Para conferir uma mudança com o
  app rodando (árvore de widgets, erros em tempo de execução, hot reload), use
  o servidor MCP do Dart (plugin Dart and Flutter).
- `flutter-reviewer` (plugin Very Good AI): só como segunda opinião de
  engenharia, nunca no lugar do `ui-reviewer`. O plugin assume BLoC,
  `very_good_analysis` e arquitetura em camadas; este projeto usa controladores
  e `flutter_lints`, então descarte sugestões que só sigam esse estilo. Os
  ganchos dele rodam `dart format` e `dart analyze` sem `fvm`: não conte com
  eles; a verificação oficial continua sendo
  `fvm flutter analyze && fvm flutter test`.

## Plugin EGM (Elephant-Goldfish Model)

EGM artifact directory: docs/designs

Briefs, rascunhos e relatórios dos comandos `/egm:...` (brainstorm, draft,
review, drift report) ficam nessa pasta, e as especificações aprovadas também,
em vez de soltos na raiz do projeto.
