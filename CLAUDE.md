# Instruções do projeto

- Sempre que implementar algo (feature, fix, refactor), após codificar, atualize a documentação relevante (README.md, PRODUCT.md, etc.) se a mudança afetar o que está documentado.
- Sempre que implementar algo, após codificar, rode `fvm flutter analyze && fvm flutter test` para verificar se está tudo ok.
- Feature flags são controladas por allowlist de e-mail em [lib/data/recursos.dart](lib/data/recursos.dart) (conversas, planos personalizados, voz, etc.). Use esse mecanismo em vez de reimplementar gating na mão.
- O arquivo `.env.json` na raiz precisa existir localmente (chaves Firebase/Gemini) para rodar o app; não versionar o conteúdo dele.
