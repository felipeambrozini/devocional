# Devocionais nos planos de leitura do usuário

Data: 2026-08-31

## Contexto

Hoje os devocionais (manhã/noite em `assets/devocionais/manha_e_noite.json` e
promessas em `assets/devocionais/promessas_de_deus.json`) são indexados só por
data de calendário (chave `DD-MM`, 366 entradas fixas por ano), sem nenhuma
ligação estruturada com livro/capítulo bíblico. Cada entrada cita uma
referência textual (`referencia`, ex. "Josué 5:12") usada hoje só para exibir
o versículo em destaque.

Os planos de leitura do usuário (`PlanoDoUsuario` /
`montarPlanoDeLeitura` em `lib/data/planos.dart`) são montados sob medida a
partir de uma lista de livros escolhidos + número de dias; cada dia
(`DiaDePlanoDoUsuario`) hoje carrega só `faixas: List<Faixa>` (referência
bíblica pura). Os dias nunca são persistidos — são recalculados a partir da
"receita" (`PlanoDoUsuario`) toda vez que o plano é aberto.

O cronograma anual fixo (`assets/reading_plan.json`) fica **fora de escopo**
desta feature.

## Objetivo

Permitir que, ao montar um plano de leitura do usuário, a pessoa opte por
incluir os devocionais cujos versículos citados caem dentro dos capítulos do
plano, escolhendo se cada devocional aparece antes ou depois do capítulo
correspondente.

## Decisões (confirmadas com o usuário)

- Escopo: só planos do usuário, não o cronograma anual.
- Ligação livro↔devocional: derivada automaticamente da string `referencia`
  de cada entrada de devocional (via `faixasDaReferencia` em
  `lib/data/canon.dart`), sem reclassificação manual dos JSONs.
- Granularidade do match: por capítulo dentro do intervalo da `Faixa` (uma
  `Faixa` pode cobrir vários capítulos consecutivos do mesmo livro).
- Múltiplos matches num mesmo capítulo: mostrar todos (manhã + noite +
  promessas de anos/dias diferentes que citem o mesmo capítulo), sem
  descartar nenhum.
- Capítulo sem match: nada é exibido, sem placeholder.
- Posição (antes/depois): escolha única por plano, feita na criação do
  plano — não por item individual.
- Ativação: opt-in via checkbox (default desmarcado) — nunca automático.

## Design técnico

### Abordagem escolhida: derivar na montagem, sem mudar schema persistido

`DiaDePlanoDoUsuario` deixa de expor `faixas: List<Faixa>` e passa a expor
`itens: List<ItemDoDia>`. Nada relacionado a devocional é persistido — só 2
campos novos na receita (`PlanoDoUsuario`). Os dias já são recalculados a
cada carregamento do plano (local ou compartilhado via Firestore), então a
interpolação dos devocionais é só um detalhe de "como montar a lista de
exibição do dia", recomputado sempre a partir do índice global carregado em
`Conteudo`.

Alternativa descartada: modelar `ItemDoDia` como tipo persistido em todo o
pipeline (incluindo serialização Firestore). Rejeitada por não trazer
benefício real — os dias nunca são persistidos hoje, só a receita.

### Novo tipo `ItemDoDia`

Em `lib/data/modelos/cronograma.dart`, ao lado de `Faixa`:

```dart
sealed class ItemDoDia {
  const ItemDoDia();
  factory ItemDoDia.capitulo(Faixa faixa) = ItemDeCapitulo;
  factory ItemDoDia.devocional(TipoDeDevocional tipo, String chaveDoDia) = ItemDeDevocional;
}

final class ItemDeCapitulo extends ItemDoDia {
  final Faixa faixa;
  const ItemDeCapitulo(this.faixa);
}

final class ItemDeDevocional extends ItemDoDia {
  final TipoDeDevocional tipo; // manha | noite | promessa
  final String chaveDoDia; // 'DD-MM', reaproveita o formato já usado pelos devocionais
  const ItemDeDevocional(this.tipo, this.chaveDoDia);
}
```

`TipoDeDevocional` pode reaproveitar/estender o `Periodo` (manhã/noite) já
existente em `lib/data/modelos/devocional.dart`, adicionando a variante
`promessa`.

### Índice livro+capítulo → devocionais

Em `Conteudo`, junto do carregamento existente dos 3 JSONs
(`_carregarDevocionais`, `_carregarPromessas`), construir uma vez:

```dart
Map<String, List<ItemDeDevocional>> _indiceDevocionaisPorCapitulo;
// chave: "$livroSlug-$capitulo", ex. "josue-5"
```

Para cada entrada de devocional, usar `faixasDaReferencia(entrada.referencia)`
(já existente em `lib/data/canon.dart`) para obter `(Livro, capitulo, ...)` e
indexar por `"${livro.slug}-$capitulo"`. Entradas cuja referência não
parseia são simplesmente ignoradas (não geram erro).

Expor um método de leitura, ex.:

```dart
List<ItemDeDevocional> devocionaisDoCapitulo(String livroSlug, int capitulo)
```

### `PlanoDoUsuario` — novos campos

```dart
final bool incluirDevocionais; // default false
final bool devocionalAntes;    // default true; só relevante se incluirDevocionais
```

Persistidos junto com os campos existentes (local e Firestore via
`lib/data/planos_nuvem.dart`). Planos antigos sem esses campos no
JSON/documento devem desserializar com os defaults acima (compatibilidade
retroativa).

### `montarPlanoDeLeitura`

Assinatura ganha os 2 parâmetros novos. Após montar as `Faixa`s de um dia
como hoje, se `incluirDevocionais`, para cada `Faixa` buscar no índice todos
os devocionais de cada capítulo no intervalo `[deCapitulo, ateCapitulo]`,
concatenar (sem duplicar) e interpolar a lista resultante antes ou depois do
`ItemDeCapitulo` correspondente, conforme `devocionalAntes`. O retorno de
`DiaDePlanoDoUsuario` passa a ser `itens: List<ItemDoDia>` em vez de
`faixas: List<Faixa>`.

### UI — `CartaoDeDia` e `BotaoDeDevocional`

`CartaoDeDia` (lib/widgets/cartao_de_dia.dart) passa a iterar
`itens: List<ItemDoDia>` em vez de `faixas: List<Faixa>`, despachando por
tipo:
- `ItemDeCapitulo` → `BotaoDeFaixa` (já existente, sem mudança de
  comportamento).
- `ItemDeDevocional` → novo `BotaoDeDevocional` (lib/widgets/faixa.dart),
  visualmente distinto (ícone por tipo: manhã/noite/promessa), que navega
  via `GoRouter.of(context).go('/${tipo.name}?data=$dataIso')` — reaproveita
  o mecanismo de deep-link por data já existente (`lib/main.dart:427-441`,
  `_dataDaRota`). A conversão de `chaveDoDia` ('DD-MM') para data ISO
  completa reaproveita a mesma lógica de ano já usada por
  `lib/telas/devocional.dart` para resolver chaves de devocional.

A aba do cronograma (`_AbaDoCronograma` em `lib/telas/plano.dart`), que
continua só com `Faixa`, faz o wrap trivial:
`faixas.map(ItemDoDia.capitulo).toList()` ao chamar `CartaoDeDia`.

### `TelaNovoPlano` — UI de configuração

Novo checkbox "Incluir devocionais dos livros" (default desmarcado). Ao
marcar, revela um seletor (ex. `SegmentedButton` ou dois `RadioListTile`)
"Antes do capítulo" / "Depois do capítulo" (default: antes). Ambos os
valores alimentam a prévia ao vivo (que já chama `montarPlanoDeLeitura`) e
são salvos no `PlanoDoUsuario` ao confirmar.

## Compatibilidade e erros

- Planos existentes (local/Firestore) sem os 2 campos novos: desserializam
  com `incluirDevocionais=false`, comportamento idêntico a hoje.
- Referência de devocional que não parseia: ignorada silenciosamente na
  construção do índice.
- Capítulo sem devocional correspondente: nenhum item extra, sem
  placeholder.

## Testes

- Unitário do índice: para uma referência conhecida (ex. "Josué 5:12"),
  `devocionaisDoCapitulo('josue', 5)` retorna a entrada esperada.
- Unitário de `montarPlanoDeLeitura` com as 4 combinações de flags
  (`incluirDevocionais` × `devocionalAntes`), conferindo a ordem dos itens
  em `itens`.
- Unitário de compatibilidade: `PlanoDoUsuario` desserializado sem os campos
  novos monta plano idêntico ao comportamento atual.
- `fvm flutter analyze && fvm flutter test` completo antes de concluir,
  conforme regra do projeto.

## Fora de escopo

- Cronograma anual fixo (`assets/reading_plan.json`).
- Granularidade de "lido" por item (continua por dia inteiro).
- Reclassificação manual dos JSONs de devocional.
