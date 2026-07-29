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
- **A virada manhã/noite segue o sol do lugar, não um horário fixo.** `lib/data/sol.dart`
  calcula nascer e pôr do sol pelo algoritmo do NOAA, sem rede e sem chave de API,
  com erro menor que dois minutos (`test/sol_test.dart` confere contra tabelas
  publicadas em três cidades). `Periodo.peloSol` usa isso; sem localização
  conhecida, ou nos círculos polares onde pode não haver nascer nem pôr do sol,
  cai no recurso das 18h (`Periodo.pelaHora`). Antes do nascer do sol ainda é
  noite, de propósito.
- **A localização é aproximada e opcional.** `geolocator` com `LocationAccuracy.low`,
  só `ACCESS_COARSE_LOCATION` no Android: a cidade já dá o horário do sol com
  precisão de sobra. `lib/data/localizacao.dart` falha em silêncio de propósito, e
  o último lugar conhecido fica em `SharedPreferences` para a tela abrir sem
  esperar o GPS. Sem permissão, o app funciona igual, pelo horário fixo.
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
