# Onde o trabalho parou

Documento de passagem de bastão. Escrito para que uma sessão nova continue sem
precisar reconstruir nenhuma decisão.

## Estado

| Item | Situação |
|---|---|
| App Flutter (mobile + web) | Completo. `flutter analyze` limpo, 458 testes passando |
| BKJ 1611 | 66 livros, 1189 capítulos, **31.102 versículos, bate exatamente com o canon** |
| NVT | 31.104 versículos; os 2 desvios são `3 João 1:15` e `Ap 12:18`, versificação da NLT |
| Manhã e Noite | 366 dias, todos com manhã e noite |
| Cronograma anual | 365 dias, 449 faixas |
| 66 introduções | Completas, com as frases aplicadas |
| **Promessas de Deus** | **366 de 366 traduzidos. Concluído.** |

## Não há tarefa de conteúdo pendente

Todo o conteúdo está carregado e verificado. O que segue é referência para
quem precisar regenerar ou revisar algo.

## Como regenerar Promessas de Deus

A fonte em inglês (`tools/promessas_en.json`) está no `.gitignore`: é insumo já
consumido, e o app lê apenas `assets/devotional/promises.json`. Para trazê-la
de volta:

```bash
curl -sL -o checkbook.txt https://www.ccel.org/ccel/s/spurgeon/checkbook/cache/checkbook.txt
python tools/promessas.py --extrair checkbook.txt
```

Conferir o que está montado e remontar o asset:

```bash
python tools/promessas.py --validar
```

```bash
python tools/promessas.py --montar
```

`--montar` deve dizer `366 de 366`. A tradução em português vive dentro do
próprio `promises.json`; os arquivos mensais intermediários de
`tools/promessas_pt/` foram removidos depois da montagem final.

## Decisões que não devem ser refeitas

- **Só se traduziu `title` e `body`.** O versículo em português **não é traduzido**: o
  script lê da BKJ já extraída em `assets/bible/bkj/`, pela referência inglesa, e
  monta `reference` em português. Isso garante que a promessa seja idêntica ao texto
  que o usuário lê no leitor da Bíblia. As 366 referências resolvem
  (`python tools/promessas.py --referencias`).
- **A fonte em inglês é a edição digital do CCEL**, não o Internet Archive. As duas
  digitalizações do Archive foram testadas e descartadas: o OCR corrompeu os
  cabeçalhos de dia (`Feb. iz` em vez de `Feb. 12`) e setembro inteiro desaparecia.
  *Faith's Checkbook* (1888) é domínio público.
- **Sem travessões** em nenhum texto do app, por pedido do usuário. Vírgula, ponto e
  vírgula ou ponto.
- **Voz vitoriana de Spurgeon**, em português, tratando o leitor por tu.
- **29 de fevereiro** não precisa de tratamento especial: `DateTime` do Dart já o
  impede em ano comum. Provado em `test/bissexto_test.dart`.
- **As 66 frases das introduções** vieram de uma lista do usuário e estão registradas
  com a referência de cada uma em `tools/frases_verificadas.json`. Só a de Salmos foi
  conferida por mim na fonte primária; isso está anotado no arquivo. Decisão do
  usuário, já discutida, não reabrir.
- **A virada manhã/noite é por horário fixo do aparelho, não pelo sol do lugar.**
  0h-17h59 é devocional da manhã, 18h-23h59 é da noite (`Periodo.pelaHora` em
  `lib/data/modelos.dart`, `test/periodo_test.dart`). A versão anterior calculava
  nascer e pôr do sol por geolocalização (`lib/data/sol.dart`,
  `lib/data/localizacao.dart`, pacote `geolocator`); tudo isso foi removido, junto
  das permissões de localização em Android, iOS e macOS.
- **O ícone sai da foto, recortado no rosto.** As fontes ficam em `assets/icone/`
  e os arquivos por plataforma são gerados por `dart run flutter_launcher_icons`,
  nunca editados à mão. Três fontes, e cada uma existe por um motivo:
  `icone.png` (rosto ocupando 88%, fundo `#2E1B10`) para iOS, macOS, Windows,
  Android legado e favicon; `icone_adaptativo.png` (60%, fundo transparente)
  para a camada de frente do ícone adaptativo do Android, que o sistema recorta
  em círculo, folha ou pílula; `icone_mascaravel.png` (60%, fundo chapado) para
  os `Icon-maskable-*` da web, porque o Chrome recorta em círculo e descarta os
  20% de fora. O gerador copia o ícone normal nos maskable, o que cortaria o
  topo da cabeça, e gera o favicon em 16, embaçado em tela de retina; por isso
  `tools/icones.py --corrigir` reescreve esses três depois dele. A ordem
  completa, se precisar refazer:

```bash
python tools/icones.py --fontes
```

```bash
dart run flutter_launcher_icons
```

```bash
python tools/icones.py --corrigir
```
- **O alternador das três leituras usa chips, não `SegmentedButton`.** O
  `SegmentedButton` iguala a largura de todos os segmentos à do maior, então três
  vezes "Promessas de Deus" nunca cabe num celular e o rótulo aparecia cortado.
  Cada chip se dimensiona pelo próprio texto.

## Comandos de regeneração de conteúdo

```bash
python tools/extract.py --bibles --devotional --plan
```

```bash
python tools/extract.py --validate
```

```bash
python tools/aplicar_frases.py
```

Os PDFs de origem ficam em `~/Downloads` e fora do repositório.

## Testes

```bash
.fvm/flutter_sdk/bin/flutter test
```
