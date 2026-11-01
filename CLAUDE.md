# Instruções do projeto

- Sempre que implementar algo (feature, fix, refactor), após codificar, atualize a documentação relevante (README.md, PRODUCT.md, etc.) se a mudança afetar o que está documentado.
- Sempre que implementar algo, após codificar, rode `fvm flutter analyze && fvm flutter test` para verificar se está tudo ok.
- Feature flags são controladas no Firestore (`config/recursos`, ver [lib/dados/config_admin.dart](lib/dados/config_admin.dart)) — interruptores booleanos e allowlists de e-mail — lidas por [lib/dados/recursos.dart](lib/dados/recursos.dart) (conversas, planos personalizados, voz, etc.). O painel `/admin` (só web e só o dono) edita sem reimplantar. Use esse mecanismo em vez de reimplementar gating na mão.
- O arquivo `.env.json` na raiz precisa existir localmente (chaves Firebase/Gemini) para rodar o app; não versionar o conteúdo dele.
- Versionamento (`version: X.Y.Z+N` em `pubspec.yaml`): o Android só atualiza por cima de um build com `+N` maior, então o `+N` nunca volta atrás nem é zerado. Funcionalidade nova sobe a minor **e** o `+N` (`1.13.0+30` → `1.14.0+31`); bug fix sobe só o `+N`. Bumpe quando o push para `main` estiver prestes a acontecer. Refactor, ajuste de texto/documentação e iteração local não mexem na versão.
- Trabalhe sempre direto na branch `main`. Nunca crie branch nem worktree para implementar tarefas deste projeto — nada de isolamento por branch/worktree, mesmo quando um skill ou processo sugerir isso por padrão.
- Sempre que implementar uma nova funcionalidade, após codificar, use o plugin playwright para testar a mudança na versão web do projeto.
- Sempre que uma tela (`lib/telas/`) ou widget de UI (`lib/widgets/`) for criado ou alterado, após codificar, rode o agente `ui-reviewer` nos arquivos mudados e corrija os achados de gravidade alta antes de dar a tarefa por concluída.
