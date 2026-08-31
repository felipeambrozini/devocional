# Instruções do projeto

- Sempre que implementar algo (feature, fix, refactor), após codificar, atualize a documentação relevante (README.md, PRODUCT.md, etc.) se a mudança afetar o que está documentado.
- Sempre que implementar algo, após codificar, rode `fvm flutter analyze && fvm flutter test` para verificar se está tudo ok.
- Feature flags são controladas por allowlist de e-mail em [lib/data/recursos.dart](lib/data/recursos.dart) (conversas, planos personalizados, voz, etc.). Use esse mecanismo em vez de reimplementar gating na mão.
- O arquivo `.env.json` na raiz precisa existir localmente (chaves Firebase/Gemini) para rodar o app; não versionar o conteúdo dele.
- Sempre que implementar algo, após codificar, bumpe o build number em `pubspec.yaml` (`version: X.Y.Z+N`, incremente o `N`) — o push para `main` fica por conta do usuário, mas o commit já deve sair com a versão nova. Sem isso, todo build do Firebase App Distribution (`.github/workflows/distribute-android.yml`/`distribute-ios.yml`) fica com a mesma versão, e o testador não consegue saber se está numa build desatualizada — foi essa a causa de um bug de notificação que parecia não ter fix nenhum, quando na real era só build velha instalada.
- Trabalhe sempre direto na branch `main`. Nunca crie branch nem worktree para implementar tarefas deste projeto — nada de isolamento por branch/worktree, mesmo quando um skill ou processo sugerir isso por padrão.
