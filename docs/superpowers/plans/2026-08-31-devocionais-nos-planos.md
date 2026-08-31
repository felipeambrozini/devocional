# Devocionais nos Planos de Leitura — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir que um plano de leitura do usuário inclua, opcionalmente, os devocionais (Manhã, Noite, Promessas) cujos versículos citados caem dentro dos capítulos do plano, antes ou depois do capítulo correspondente.

**Architecture:** Um índice livro+capítulo → devocionais é construído uma vez em `Conteudo`, a partir da referência bíblica já citada em cada devocional (reaproveitando `faixasDaReferencia` de `canon.dart`). `montarPlanoDeLeitura` passa a poder intercalar esses devocionais entre as faixas de capítulo de cada dia, guardados num novo tipo `ItemDoDia` (capítulo ou devocional). Nada de devocional é persistido: só 2 flags novas na receita do plano (`PlanoDoUsuario`).

**Tech Stack:** Flutter/Dart, go_router (navegação), Firestore (planos compartilhados), flutter_test.

**Spec:** [docs/superpowers/specs/2026-08-31-devocionais-nos-planos-design.md](../specs/2026-08-31-devocionais-nos-planos-design.md)

## Global Constraints

- Rode `fvm flutter analyze && fvm flutter test` (via `fvm`, não `flutter` direto) depois de cada task, e obrigatoriamente antes de considerar o trabalho concluído.
- Ao final de toda a implementação, atualize a documentação afetada (README.md, PRODUCT.md) e bumpe o build number em `pubspec.yaml` (`version: X.Y.Z+N`, incremente só o `N`) — uma vez, no fim, não a cada commit.
- Escopo só planos do usuário — o cronograma anual fixo (`assets/reading_plan.json`, `DiaDoPlano`) não muda.
- `DiaDePlanoDoUsuario.faixas` deve continuar funcionando como getter derivado, sem quebrar nenhum teste existente que já usa `dia.faixas`.
- `PlanoDoUsuario.diasDoPlano` continua um getter sem argumentos — a fonte dos devocionais é lida de dentro de `Conteudo`, não passada por fora.

---

### Task 1: `TipoDeDevocional` e `ItemDoDia` (capítulo ou devocional)

**Files:**
- Modify: `lib/data/modelos/cronograma.dart`
- Test: `test/cronograma_test.dart` (novo arquivo)

**Interfaces:**
- Produces: `TipoDeDevocional` (enum: `manha`, `noite`, `promessa`, campos `rota`/`nome`), `sealed class ItemDoDia`, `ItemDeCapitulo(Faixa faixa)`, `ItemDeDevocional({required TipoDeDevocional tipo, required String chaveDoDia})` — usados pela Task 3 (montagem do plano) e Task 6 (widgets).

- [ ] **Step 1: Escrever o teste que falha**

```dart
// test/cronograma_test.dart
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TipoDeDevocional', () {
    test('rota bate com o path das 3 leituras (/manha, /noite, /promessas)', () {
      expect(TipoDeDevocional.manha.rota, 'manha');
      expect(TipoDeDevocional.noite.rota, 'noite');
      expect(TipoDeDevocional.promessa.rota, 'promessas');
    });
  });

  group('ItemDoDia', () {
    test('ItemDeCapitulo guarda a faixa', () {
      const faixa = Faixa(livro: 'genesis', deCapitulo: 1, ateCapitulo: 3);
      const item = ItemDeCapitulo(faixa);
      expect(item.faixa, faixa);
    });

    test('ItemDeDevocional guarda tipo e chave do dia', () {
      const item = ItemDeDevocional(
        tipo: TipoDeDevocional.noite,
        chaveDoDia: '05-01',
      );
      expect(item.tipo, TipoDeDevocional.noite);
      expect(item.chaveDoDia, '05-01');
    });
  });
}
```

- [ ] **Step 2: Rodar e verificar que falha**

Run: `fvm flutter test test/cronograma_test.dart`
Expected: FAIL — `TipoDeDevocional`/`ItemDoDia`/`ItemDeCapitulo`/`ItemDeDevocional` não existem.

- [ ] **Step 3: Implementar**

Adicionar ao final de `lib/data/modelos/cronograma.dart` (depois de `DiaDoPlano`):

```dart
/// As três leituras diárias que podem ser citadas por um capítulo do plano.
/// `rota` bate com o path que `main.dart` declara para cada uma (`/manha`,
/// `/noite`, `/promessas`) e com `Leitura.name` em `lib/telas/devocional.dart`.
enum TipoDeDevocional {
  manha('manha', 'Manhã'),
  noite('noite', 'Noite'),
  promessa('promessas', 'Promessa');

  const TipoDeDevocional(this.rota, this.nome);

  final String rota;
  final String nome;
}

/// Um item do dia de um plano do usuário: um capítulo, ou um devocional cujo
/// versículo citado cai dentro de um capítulo do dia (ver
/// [Conteudo.devocionaisDoCapitulo] e [montarPlanoDeLeitura]).
sealed class ItemDoDia {
  const ItemDoDia();
}

/// Um capítulo (ou faixa de capítulos) do dia.
final class ItemDeCapitulo extends ItemDoDia {
  const ItemDeCapitulo(this.faixa);

  final Faixa faixa;
}

/// Um devocional citado por um capítulo do dia. [chaveDoDia] é a chave
/// 'DD-MM' do devocional em si — não tem relação com a posição do dia no
/// plano do usuário, que não tem data.
final class ItemDeDevocional extends ItemDoDia {
  const ItemDeDevocional({required this.tipo, required this.chaveDoDia});

  final TipoDeDevocional tipo;
  final String chaveDoDia;

  @override
  bool operator ==(Object other) =>
      other is ItemDeDevocional &&
      other.tipo == tipo &&
      other.chaveDoDia == chaveDoDia;

  @override
  int get hashCode => Object.hash(tipo, chaveDoDia);
}
```

- [ ] **Step 4: Rodar e verificar que passa**

Run: `fvm flutter test test/cronograma_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/modelos/cronograma.dart test/cronograma_test.dart
git commit -m "Adiciona ItemDoDia (capítulo ou devocional) ao modelo de plano"
```

---

### Task 2: Índice livro+capítulo → devocionais em `Conteudo`

**Files:**
- Modify: `lib/data/conteudo.dart`
- Test: `test/conteudo_test.dart`

**Interfaces:**
- Consumes: `ItemDeDevocional`, `TipoDeDevocional` (Task 1); `faixasDaReferencia` (`lib/data/canon.dart`, já existente); `Conteudo._carregarDevocionais()`/`_carregarPromessas()` (já existentes).
- Produces: `Future<void> Conteudo.aquecerIndiceDeDevocionais()`, `List<ItemDeDevocional> Conteudo.devocionaisDoCapitulo(String livroSlug, int capitulo)` — usados pela Task 3.

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao final de `test/conteudo_test.dart` (o arquivo já chama `TestWidgetsFlutterBinding.ensureInitialized()` no topo do `main()`, necessário para `rootBundle`):

```dart
  group('índice de devocionais por capítulo', () {
    test('Gênesis 1 encontra os devocionais de 05-01 (manhã e noite)', () async {
      await Conteudo.instancia.aquecerIndiceDeDevocionais();
      final achados = Conteudo.instancia.devocionaisDoCapitulo('genesis', 1);

      expect(
        achados,
        containsAll([
          const ItemDeDevocional(
            tipo: TipoDeDevocional.manha,
            chaveDoDia: '05-01',
          ),
          const ItemDeDevocional(
            tipo: TipoDeDevocional.noite,
            chaveDoDia: '05-01',
          ),
        ]),
      );
    });

    test('capítulo sem nenhum devocional devolve lista vazia', () async {
      await Conteudo.instancia.aquecerIndiceDeDevocionais();
      // Números não é citado por nenhum devocional nos assets atuais.
      expect(Conteudo.instancia.devocionaisDoCapitulo('numeros', 36), isEmpty);
    });
  });
```

Isto exige que `ItemDeDevocional` tenha `==`/`hashCode` por valor para `containsAll` funcionar — adicionar no Step 3.

- [ ] **Step 2: Rodar e verificar que falha**

Run: `fvm flutter test test/conteudo_test.dart`
Expected: FAIL — `aquecerIndiceDeDevocionais`/`devocionaisDoCapitulo` não existem.

- [ ] **Step 3: Implementar**

(`ItemDeDevocional` já tem `==`/`hashCode` por valor desde a Task 1, o que faz o `containsAll` do teste funcionar.)

Em `lib/data/conteudo.dart`, adicionar (perto de `_carregarPromessas`, antes de `buscarDevocionais`):

```dart
  Map<String, List<ItemDeDevocional>>? _indiceDeDevocionais;
  Future<void>? _carregandoIndiceDeDevocionais;

  /// Garante que o índice livro+capítulo → devocionais está carregado.
  /// Idempotente: chamadas repetidas reaproveitam o mesmo carregamento, do
  /// mesmo jeito que [_carregarLivro] cacheia por slug.
  Future<void> aquecerIndiceDeDevocionais() =>
      _carregandoIndiceDeDevocionais ??= _montarIndiceDeDevocionais();

  Future<void> _montarIndiceDeDevocionais() async {
    final indice = <String, List<ItemDeDevocional>>{};

    final devocionais = await _carregarDevocionais();
    for (final MapEntry(key: chave, value: dia) in devocionais.entries) {
      for (final periodo in Periodo.values) {
        final entrada = dia[periodo.chave] as Map<String, dynamic>?;
        if (entrada == null) continue;
        _indexarReferencia(
          indice,
          entrada['referencia'] as String? ?? '',
          periodo == Periodo.manha
              ? TipoDeDevocional.manha
              : TipoDeDevocional.noite,
          chave,
        );
      }
    }

    final promessas = await _carregarPromessas();
    if (promessas != null) {
      for (final MapEntry(key: chave, value: entrada) in promessas.entries) {
        _indexarReferencia(
          indice,
          entrada['referencia'] as String? ?? '',
          TipoDeDevocional.promessa,
          chave,
        );
      }
    }

    _indiceDeDevocionais = indice;
  }

  void _indexarReferencia(
    Map<String, List<ItemDeDevocional>> indice,
    String referencia,
    TipoDeDevocional tipo,
    String chaveDoDia,
  ) {
    for (final (livro, capitulo, _, _) in faixasDaReferencia(referencia)) {
      final chaveIndice = '${livro.slug}-$capitulo';
      (indice[chaveIndice] ??= []).add(
        ItemDeDevocional(tipo: tipo, chaveDoDia: chaveDoDia),
      );
    }
  }

  /// Os devocionais (Manhã, Noite, Promessas) cuja referência cita este
  /// capítulo. Vazio se [aquecerIndiceDeDevocionais] ainda não terminou, ou
  /// se nenhum devocional cita este capítulo — os dois casos são o mesmo
  /// "nada a mostrar" para quem monta um plano (ver [montarPlanoDeLeitura]).
  List<ItemDeDevocional> devocionaisDoCapitulo(String livroSlug, int capitulo) =>
      _indiceDeDevocionais?['$livroSlug-$capitulo'] ?? const [];
```

- [ ] **Step 4: Rodar e verificar que passa**

Run: `fvm flutter test test/conteudo_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/conteudo.dart lib/data/modelos/cronograma.dart test/conteudo_test.dart
git commit -m "Indexa devocionais por livro+capítulo em Conteudo"
```

---

### Task 3: `montarPlanoDeLeitura` intercala devocionais

**Files:**
- Modify: `lib/data/planos.dart`
- Test: `test/planos_test.dart`

**Interfaces:**
- Consumes: `ItemDoDia`, `ItemDeCapitulo`, `ItemDeDevocional`, `TipoDeDevocional` (Task 1); `Conteudo.instancia.devocionaisDoCapitulo` (Task 2).
- Produces: `DiaDePlanoDoUsuario.itens: List<ItemDoDia>` (novo), `DiaDePlanoDoUsuario.faixas` (getter derivado, mesmo comportamento de antes), `montarPlanoDeLeitura(..., incluirDevocionais, devocionalAntes)` — usado pela Task 4 (`PlanoDoUsuario.diasDoPlano`).

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao `group('montarPlanoDeLeitura', ...)` em `test/planos_test.dart`, e aquecer o índice no `setUp` do arquivo (widget binding já existe via `flutter_test`; usar `setUpAll` para carregar uma vez):

```dart
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Conteudo.instancia.aquecerIndiceDeDevocionais();
  });
```

(adicionar o import `package:flutter_test/flutter_test.dart` já existe; adicionar também `import 'package:felipe_ambrozini/data/modelos.dart';` no topo do arquivo, para `ItemDeCapitulo`/`ItemDeDevocional`/`TipoDeDevocional`.)

```dart
    test('sem incluirDevocionais, itens são só ItemDeCapitulo', () {
      final dia = montarPlanoDeLeitura(livros: ['genesis'], dias: 50)[0];
      expect(dia.itens, [isA<ItemDeCapitulo>()]);
    });

    test('incluirDevocionais=true intercala os devocionais do capítulo, '
        'na posição pedida', () {
      // Dia 1 é só Gênesis 1 (50 capítulos em 50 dias). Vários devocionais do
      // ano citam Gênesis 1 (ex. 05-01, manhã e noite, citando Gênesis 1:4 —
      // ver test/conteudo_test.dart); não importa quantos são ao todo, só que
      // entram todos e na posição certa em relação ao capítulo.
      final antes = montarPlanoDeLeitura(
        livros: ['genesis'],
        dias: 50,
        incluirDevocionais: true,
      )[0];
      expect(antes.itens.last, isA<ItemDeCapitulo>());
      expect(
        antes.itens.whereType<ItemDeDevocional>(),
        contains(
          isA<ItemDeDevocional>()
              .having((i) => i.tipo, 'tipo', TipoDeDevocional.manha)
              .having((i) => i.chaveDoDia, 'chaveDoDia', '05-01'),
        ),
      );

      final depois = montarPlanoDeLeitura(
        livros: ['genesis'],
        dias: 50,
        incluirDevocionais: true,
        devocionalAntes: false,
      )[0];
      expect(depois.itens.first, isA<ItemDeCapitulo>());
      // Mesmo conjunto de devocionais, só muda de lado do capítulo.
      expect(depois.itens.length, antes.itens.length);
    });

    test('faixas continua exposto e ignora os itens de devocional', () {
      final dia = montarPlanoDeLeitura(
        livros: ['genesis'],
        dias: 50,
        incluirDevocionais: true,
      )[0];
      expect(dia.faixas, hasLength(1));
      expect(dia.faixas.single.rotulo, 'Gênesis 1');
      expect(dia.rotulo, 'Gênesis 1');
    });
```

- [ ] **Step 2: Rodar e verificar que falha**

Run: `fvm flutter test test/planos_test.dart`
Expected: FAIL — `montarPlanoDeLeitura` não aceita `incluirDevocionais`/`devocionalAntes`, e `DiaDePlanoDoUsuario` não tem `itens`.

- [ ] **Step 3: Implementar**

Em `lib/data/planos.dart`, adicionar o import e trocar `DiaDePlanoDoUsuario`:

```dart
import 'conteudo.dart';
```

```dart
class DiaDePlanoDoUsuario {
  const DiaDePlanoDoUsuario({required this.numero, required this.itens});

  /// Posição do dia no plano, de 1 em diante. É a chave de progresso.
  final int numero;

  final List<ItemDoDia> itens;

  /// Só as faixas de capítulo do dia, na ordem, sem os devocionais
  /// intercalados — o que a maioria do código precisa (rótulo, contagem de
  /// capítulos, o botão que abre a Bíblia).
  List<Faixa> get faixas => [
    for (final item in itens)
      if (item is ItemDeCapitulo) item.faixa,
  ];

  String get rotulo => faixas.map((f) => f.rotulo).join(', ');
}
```

E `montarPlanoDeLeitura`:

```dart
List<DiaDePlanoDoUsuario> montarPlanoDeLeitura({
  required List<String> livros,
  required int dias,
  bool incluirDevocionais = false,
  bool devocionalAntes = true,
}) {
  final capitulos = <(String, int)>[];
  for (final slug in livros) {
    final livro = livroPorSlug(slug);
    if (livro == null) continue;
    for (var numero = 1; numero <= livro.capitulos; numero++) {
      capitulos.add((slug, numero));
    }
  }
  if (capitulos.isEmpty) return const [];
  if (dias < 1) return const [];

  final porDia = capitulos.length / dias;
  final plano = <DiaDePlanoDoUsuario>[];
  for (var dia = 0; dia < dias; dia++) {
    final de = (dia * porDia).round();
    final ate = ((dia + 1) * porDia).round();
    if (ate <= de) continue;
    final faixas = _agruparEmFaixas(capitulos.sublist(de, ate));
    plano.add(
      DiaDePlanoDoUsuario(
        numero: plano.length + 1,
        itens: incluirDevocionais
            ? _itensComDevocionais(faixas, devocionalAntes)
            : [for (final f in faixas) ItemDeCapitulo(f)],
      ),
    );
  }
  return plano;
}

/// Para cada faixa, busca os devocionais de cada capítulo que ela cobre e os
/// intercala antes ou depois do [ItemDeCapitulo] correspondente.
List<ItemDoDia> _itensComDevocionais(List<Faixa> faixas, bool antes) {
  final itens = <ItemDoDia>[];
  for (final faixa in faixas) {
    final devocionais = [
      for (final capitulo in faixa.capitulos)
        ...Conteudo.instancia.devocionaisDoCapitulo(faixa.livro, capitulo),
    ];
    if (antes) itens.addAll(devocionais);
    itens.add(ItemDeCapitulo(faixa));
    if (!antes) itens.addAll(devocionais);
  }
  return itens;
}
```

`_agruparEmFaixas` não muda.

- [ ] **Step 4: Rodar e verificar que passa**

Run: `fvm flutter test test/planos_test.dart`
Expected: PASS — inclusive todos os testes já existentes que leem `dia.faixas`, sem alteração neles.

- [ ] **Step 5: Commit**

```bash
git add lib/data/planos.dart test/planos_test.dart
git commit -m "montarPlanoDeLeitura intercala devocionais quando pedido"
```

---

### Task 4: `PlanoDoUsuario` ganha `incluirDevocionais`/`devocionalAntes`

**Files:**
- Modify: `lib/data/planos.dart`
- Test: `test/planos_test.dart`

**Interfaces:**
- Produces: `PlanoDoUsuario.incluirDevocionais`, `PlanoDoUsuario.devocionalAntes` (defaults `false`/`true`), refletidos em `doJson`, `doJsonDaNuvem`, `compartilhadoComo`, `paraJson`, `diasDoPlano` — usados pela Task 5 (criação/compartilhamento) e Task 7 (UI).

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao `group('PlanoDoUsuario', ...)`:

```dart
    test('incluirDevocionais/devocionalAntes por padrão são false/true, '
        'e paraJson/doJson preservam quando setados', () {
      final padrao = PlanoDoUsuario(
        id: 'a',
        titulo: '',
        livros: ['genesis'],
        dias: 30,
        criadoEm: DateTime(2027),
      );
      expect(padrao.incluirDevocionais, isFalse);
      expect(padrao.devocionalAntes, isTrue);

      final comDevocionais = PlanoDoUsuario(
        id: 'b',
        titulo: '',
        livros: ['genesis'],
        dias: 30,
        criadoEm: DateTime(2027),
        incluirDevocionais: true,
        devocionalAntes: false,
      );
      final lido = PlanoDoUsuario.doJson(comDevocionais.paraJson());
      expect(lido.incluirDevocionais, isTrue);
      expect(lido.devocionalAntes, isFalse);
    });

    test('doJson sem os campos novos (plano antigo) cai no padrão', () {
      final plano = PlanoDoUsuario.doJson({
        'id': 'x',
        'titulo': 'X',
        'livros': ['genesis'],
        'dias': 10,
        'criadoEm': 0,
      });
      expect(plano.incluirDevocionais, isFalse);
      expect(plano.devocionalAntes, isTrue);
    });

    test('diasDoPlano com incluirDevocionais monta itens intercalados', () {
      final plano = PlanoDoUsuario(
        id: 'a',
        titulo: '',
        livros: ['genesis'],
        dias: 50,
        criadoEm: DateTime(2027),
        incluirDevocionais: true,
      );
      expect(
        plano.diasDoPlano[0].itens.whereType<ItemDeDevocional>(),
        isNotEmpty,
      );
    });
```

- [ ] **Step 2: Rodar e verificar que falha**

Run: `fvm flutter test test/planos_test.dart`
Expected: FAIL — `PlanoDoUsuario` não tem `incluirDevocionais`/`devocionalAntes`.

- [ ] **Step 3: Implementar**

Em `lib/data/planos.dart`, no construtor e campos de `PlanoDoUsuario`:

```dart
class PlanoDoUsuario {
  const PlanoDoUsuario({
    required this.id,
    required this.titulo,
    required this.livros,
    required this.dias,
    required this.criadoEm,
    this.compartilhado = false,
    this.criadoPor,
    this.incluirDevocionais = false,
    this.devocionalAntes = true,
  });

  factory PlanoDoUsuario.doJson(Map<String, dynamic> json) => PlanoDoUsuario(
    id: json['id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    livros: [
      for (final l in json['livros'] as List? ?? const [])
        if (l is String && livroPorSlug(l) != null) l,
    ],
    dias: json['dias'] as int? ?? 1,
    criadoEm: DateTime.fromMillisecondsSinceEpoch(
      json['criadoEm'] as int? ?? 0,
    ),
    compartilhado: json['compartilhado'] as bool? ?? false,
    criadoPor: json['criadoPor'] as String?,
    incluirDevocionais: json['incluirDevocionais'] as bool? ?? false,
    devocionalAntes: json['devocionalAntes'] as bool? ?? true,
  );

  factory PlanoDoUsuario.doJsonDaNuvem(
    Map<String, dynamic> json, {
    required String id,
    required DateTime criadoEm,
  }) => PlanoDoUsuario(
    id: id,
    titulo: json['titulo'] as String? ?? '',
    livros: [
      for (final l in json['livros'] as List? ?? const [])
        if (l is String && livroPorSlug(l) != null) l,
    ],
    dias: json['dias'] as int? ?? 1,
    criadoEm: criadoEm,
    compartilhado: true,
    criadoPor: json['criadoPor'] as String?,
    incluirDevocionais: json['incluirDevocionais'] as bool? ?? false,
    devocionalAntes: json['devocionalAntes'] as bool? ?? true,
  );

  final String id;
  final String titulo;
  final List<String> livros;
  final int dias;
  final DateTime criadoEm;
  final bool compartilhado;
  final String? criadoPor;

  /// Se o plano intercala os devocionais dos livros entre os capítulos —
  /// ver [montarPlanoDeLeitura]. Escolhido na criação do plano
  /// (`lib/telas/novo_plano.dart`), não editável depois.
  final bool incluirDevocionais;

  /// Só relevante com [incluirDevocionais]: se o devocional do capítulo
  /// aparece antes ou depois dele no dia.
  final bool devocionalAntes;

  List<DiaDePlanoDoUsuario> get diasDoPlano => montarPlanoDeLeitura(
    livros: livros,
    dias: dias,
    incluirDevocionais: incluirDevocionais,
    devocionalAntes: devocionalAntes,
  );

  int get totalDeCapitulos {
    var total = 0;
    for (final slug in livros) {
      total += livroPorSlug(slug)?.capitulos ?? 0;
    }
    return total;
  }

  PlanoDoUsuario compartilhadoComo(bool novo) => PlanoDoUsuario(
    id: id,
    titulo: titulo,
    livros: livros,
    dias: dias,
    criadoEm: criadoEm,
    compartilhado: novo,
    criadoPor: criadoPor,
    incluirDevocionais: incluirDevocionais,
    devocionalAntes: devocionalAntes,
  );

  Map<String, dynamic> paraJson() => {
    'id': id,
    'titulo': titulo,
    'livros': livros,
    'dias': dias,
    'criadoEm': criadoEm.millisecondsSinceEpoch,
    if (compartilhado) 'compartilhado': true,
    if (criadoPor != null) 'criadoPor': criadoPor,
    'incluirDevocionais': incluirDevocionais,
    'devocionalAntes': devocionalAntes,
  };
}
```

- [ ] **Step 4: Rodar e verificar que passa**

Run: `fvm flutter test test/planos_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/planos.dart test/planos_test.dart
git commit -m "PlanoDoUsuario ganha incluirDevocionais e devocionalAntes"
```

---

### Task 5: Criação e compartilhamento propagam os 2 campos novos

**Files:**
- Modify: `lib/data/estado.dart:480-498` (`criarPlano`)
- Modify: `lib/data/planos_nuvem.dart:117-142` (`compartilhar`)
- Test: `test/planos_test.dart`

**Interfaces:**
- Consumes: `PlanoDoUsuario` (Task 4).
- Produces: `Estado.criarPlano(..., incluirDevocionais, devocionalAntes)` — usado pela Task 7 (`TelaNovoPlano`).

- [ ] **Step 1: Escrever o teste que falha**

Adicionar ao `group('planos do usuário no Estado', ...)` em `test/planos_test.dart`:

```dart
    test('criarPlano aceita e persiste incluirDevocionais/devocionalAntes', () async {
      final estado = await Estado.abrir();
      final plano = await estado.criarPlano(
        titulo: '',
        livros: ['genesis'],
        dias: 30,
        incluirDevocionais: true,
        devocionalAntes: false,
      );
      expect(plano.incluirDevocionais, isTrue);
      expect(plano.devocionalAntes, isFalse);

      final relido = await reabrir();
      final planoRelido = relido.planosDoUsuario.single;
      expect(planoRelido.incluirDevocionais, isTrue);
      expect(planoRelido.devocionalAntes, isFalse);
    });
```

- [ ] **Step 2: Rodar e verificar que falha**

Run: `fvm flutter test test/planos_test.dart`
Expected: FAIL — `criarPlano` não aceita esses parâmetros nomeados.

- [ ] **Step 3: Implementar**

Em `lib/data/estado.dart:480-498`:

```dart
  Future<PlanoDoUsuario> criarPlano({
    required String titulo,
    required List<String> livros,
    required int dias,
    bool incluirDevocionais = false,
    bool devocionalAntes = true,
  }) async {
    final plano = PlanoDoUsuario(
      id: novoIdDePlano(),
      titulo: titulo.trim().isEmpty
          ? tituloDePlano(livros, dias)
          : titulo.trim(),
      livros: livros,
      dias: dias,
      criadoEm: DateTime.now(),
      incluirDevocionais: incluirDevocionais,
      devocionalAntes: devocionalAntes,
    );
    _planos.insert(0, plano);
    notifyListeners();
    await _gravarPlanos();
    return plano;
  }
```

Em `lib/data/planos_nuvem.dart:125-134` (`compartilhar`), acrescentar os 2 campos ao documento:

```dart
      await FirebaseFirestore.instance.collection(_colecao).doc(plano.id).set({
        'titulo': plano.titulo,
        'livros': plano.livros,
        'dias': plano.dias,
        'incluirDevocionais': plano.incluirDevocionais,
        'devocionalAntes': plano.devocionalAntes,
        'criadoPor': usuario.uid,
        'criadoEm': FieldValue.serverTimestamp(),
        'participantes': {
          usuario.uid: _entradaDoUsuario(usuario, const []),
        },
      });
```

(Não precisa de teste dedicado para esta segunda mudança: `compartilhar()` não tem teste de payload de Firestore hoje em `test/planos_nuvem_test.dart` — que só testa `linkDoPlano`/`idDoParametroDePlano` — e `PlanoDoUsuario.doJsonDaNuvem`, já coberto na Task 4, garante que os campos voltam corretamente na leitura.)

- [ ] **Step 4: Rodar e verificar que passa**

Run: `fvm flutter test test/planos_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/estado.dart lib/data/planos_nuvem.dart test/planos_test.dart
git commit -m "Criação e compartilhamento de plano propagam os flags de devocional"
```

---

### Task 6: `CartaoDeDia` renderiza itens intercalados; `BotaoDeDevocional`

**Files:**
- Modify: `lib/widgets/cartao_de_dia.dart`
- Modify: `lib/widgets/faixa.dart`
- Modify: `lib/telas/plano.dart:273-281` (`_AbaDoCronograma`, call site do cronograma)
- Modify: `lib/telas/meu_plano.dart:475-481` (`TelaDeUmPlano`, call site do plano do usuário)
- Test: `test/faixa_test.dart`

**Interfaces:**
- Consumes: `ItemDoDia`, `ItemDeCapitulo`, `ItemDeDevocional`, `TipoDeDevocional` (Task 1).
- Produces: `CartaoDeDia.itens` (troca `faixas`), `BotaoDeDevocional` — usado pela Task 7 nos testes de widget.

- [ ] **Step 1: Escrever o teste que falha**

Adicionar o import `import 'package:go_router/go_router.dart';` ao topo de `test/faixa_test.dart` (o arquivo já importa `package:felipe_ambrozini/data/modelos.dart`, que cobre `TipoDeDevocional`/`ItemDoDia`). Depois, adicionar ao arquivo:

```dart
  testWidgets('BotaoDeDevocional mostra o nome do tipo e navega para a rota '
      'e data certas', (tester) async {
    late final GoRouter roteador;
    roteador = GoRouter(
      initialLocation: '/inicio',
      routes: [
        GoRoute(path: '/inicio', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/noite',
          builder: (context, state) =>
              Text('data=${state.uri.queryParameters['data']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: roteador,
        builder: (context, child) => Scaffold(
          body: Column(
            children: [
              const BotaoDeDevocional(
                tipo: TipoDeDevocional.noite,
                chaveDoDia: '25-12',
              ),
              if (child != null) child,
            ],
          ),
        ),
      ),
    );

    expect(find.text('Noite'), findsOneWidget);
    await tester.tap(find.byType(BotaoDeDevocional));
    await tester.pumpAndSettle();

    final ano = DateTime.now().year;
    expect(find.text('data=$ano-12-25'), findsOneWidget);
  });
```

- [ ] **Step 2: Rodar e verificar que falha**

Run: `fvm flutter test test/faixa_test.dart`
Expected: FAIL — `BotaoDeDevocional` não existe.

- [ ] **Step 3: Implementar**

Em `lib/widgets/faixa.dart`, adicionar o import e o widget:

```dart
import 'package:go_router/go_router.dart';
```

```dart
/// Botão que abre o devocional (Manhã, Noite ou Promessas) citado por um
/// capítulo do plano, na data em que foi publicado — o conteúdo não depende
/// do ano, só do dia-mês (ver `Conteudo.chaveDoDia`).
class BotaoDeDevocional extends StatelessWidget {
  const BotaoDeDevocional({
    super.key,
    required this.tipo,
    required this.chaveDoDia,
  });

  final TipoDeDevocional tipo;
  final String chaveDoDia;

  IconData get _icone => switch (tipo) {
    TipoDeDevocional.manha => Icons.wb_sunny_outlined,
    TipoDeDevocional.noite => Icons.nights_stay_outlined,
    TipoDeDevocional.promessa => Icons.auto_awesome_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(_icone, size: 17),
      label: Text(tipo.nome),
      onPressed: () {
        final partes = chaveDoDia.split('-');
        final dia = int.parse(partes[0]);
        final mes = int.parse(partes[1]);
        final ano = DateTime.now().year;
        final parametroDeData =
            '$ano-${mes.toString().padLeft(2, '0')}-'
            '${dia.toString().padLeft(2, '0')}';
        GoRouter.of(context).go('/${tipo.rota}?data=$parametroDeData');
      },
    );
  }
}
```

Em `lib/widgets/cartao_de_dia.dart`, trocar `faixas` por `itens` e o `Wrap`:

```dart
class CartaoDeDia extends StatelessWidget {
  const CartaoDeDia({
    super.key,
    required this.numero,
    required this.rotulo,
    required this.itens,
    required this.lido,
    required this.aoAlternar,
    this.destacar = false,
  });

  final int numero;
  final String rotulo;
  final List<ItemDoDia> itens;
  final bool lido;
  final bool destacar;
  final VoidCallback aoAlternar;
```

```dart
                  Wrap(
                    spacing: Spacing.sp8,
                    runSpacing: Spacing.sp8,
                    children: [
                      for (final item in itens)
                        switch (item) {
                          ItemDeCapitulo(:final faixa) =>
                            BotaoDeFaixa(faixa: faixa),
                          ItemDeDevocional(:final tipo, :final chaveDoDia) =>
                            BotaoDeDevocional(
                              tipo: tipo,
                              chaveDoDia: chaveDoDia,
                            ),
                        },
                    ],
                  ),
```

Em `lib/telas/plano.dart:273-281` (dentro de `_AbaDoCronogramaState`, cronograma continua só com `Faixa`):

```dart
                    return CartaoDeDia(
                      key: ehHoje ? _chaveDeHoje : null,
                      numero: dia.dia,
                      rotulo: dia.rotulo,
                      itens: [for (final f in dia.faixas) ItemDeCapitulo(f)],
                      lido: estado.foiLido(dia.data),
                      destacar: ehHoje,
                      aoAlternar: () => estado.alternarLido(dia.data),
                    );
```

Em `lib/telas/meu_plano.dart:475-481` (`TelaDeUmPlano`, `dia` já é `DiaDePlanoDoUsuario`):

```dart
          return CartaoDeDia(
            numero: dia.numero,
            rotulo: dia.rotulo,
            itens: dia.itens,
            lido: _meusLidos().contains(dia.numero),
            aoAlternar: () => _alternarDia(dia.numero),
          );
```

`lib/telas/meu_plano.dart` não precisa de import novo: `dia.itens` é só repassado para `CartaoDeDia`, sem nomear o tipo `ItemDoDia` no arquivo.

- [ ] **Step 4: Rodar e verificar que passa**

Run: `fvm flutter test test/faixa_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/cartao_de_dia.dart lib/widgets/faixa.dart lib/telas/plano.dart lib/telas/meu_plano.dart test/faixa_test.dart
git commit -m "CartaoDeDia renderiza itens intercalados; novo BotaoDeDevocional"
```

---

### Task 7: `TelaNovoPlano` — checkbox e seletor antes/depois

**Files:**
- Modify: `lib/telas/novo_plano.dart`
- Test: `test/planos_test.dart` (o teste de widget existente, `'cria um plano pelo formulário e marca um dia'`, mais um novo)

**Interfaces:**
- Consumes: `Conteudo.instancia.aquecerIndiceDeDevocionais()` (Task 2), `montarPlanoDeLeitura(..., incluirDevocionais, devocionalAntes)` (Task 3), `Estado.criarPlano(..., incluirDevocionais, devocionalAntes)` (Task 5).

- [ ] **Step 1: Escrever o teste que falha**

Adicionar em `test/planos_test.dart`, dentro de `group('a tela de Meus Planos', ...)`:

```dart
    testWidgets('checkbox de devocionais mostra o seletor e cria o plano '
        'com os 2 campos', (tester) async {
      await tester.runAsync(() async {
        await Conteudo.instancia.plano(bissexto: false);
        await Conteudo.instancia.aquecerIndiceDeDevocionais();
      });
      final estado = Estado(await SharedPreferences.getInstance());
      Nuvem.instancia.logadoForcado = true;
      addTearDown(() => Nuvem.instancia.logadoForcado = null);
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(estado: estado, child: TelaNovoPlano(estado: estado)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Escolher livros'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Gênesis',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Gênesis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Incluir devocionais dos livros'), findsOneWidget);
      // Sem marcar o checkbox, o seletor antes/depois não aparece.
      expect(find.text('Antes do capítulo'), findsNothing);

      await tester.tap(find.text('Incluir devocionais dos livros'));
      await tester.pumpAndSettle();
      expect(find.text('Antes do capítulo'), findsOneWidget);
      expect(find.text('Depois do capítulo'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Criar plano'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Criar plano'));
      await tester.pumpAndSettle();

      expect(estado.planosDoUsuario.single.incluirDevocionais, isTrue);
      expect(estado.planosDoUsuario.single.devocionalAntes, isTrue);
    });
```

- [ ] **Step 2: Rodar e verificar que falha**

Run: `fvm flutter test test/planos_test.dart`
Expected: FAIL — não existe o texto "Incluir devocionais dos livros" nem o seletor.

- [ ] **Step 3: Implementar**

Em `lib/telas/novo_plano.dart`, adicionar 2 campos de estado e usá-los em `_previa`/`_criar`:

```dart
class _TelaNovoPlanoState extends State<TelaNovoPlano> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _dias = TextEditingController(text: '30');
  final List<String> _livros = [];
  bool _incluirDevocionais = false;
  bool _devocionalAntes = true;
```

```dart
  List<DiaDePlanoDoUsuario> get _previa => montarPlanoDeLeitura(
    livros: _livros,
    dias: int.tryParse(_dias.text) ?? 0,
    incluirDevocionais: _incluirDevocionais,
    devocionalAntes: _devocionalAntes,
  );
```

```dart
  Future<void> _criar() async {
    if (_livros.isEmpty) {
      mostrarAviso(context, 'Escolha pelo menos um livro.');
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    final plano = await widget.estado.criarPlano(
      titulo: _titulo.text,
      livros: _livros,
      dias: int.parse(_dias.text),
      incluirDevocionais: _incluirDevocionais,
      devocionalAntes: _devocionalAntes,
    );
    if (!mounted) return;
    Navigator.pop(context, plano);
  }
```

E no `initState`, aquecer o índice (a prévia só mostra devocionais depois que ele carrega — sem isto, marcar o checkbox não mudaria nada até a tela redesenhar por outro motivo):

```dart
  @override
  void initState() {
    super.initState();
    Conteudo.instancia.aquecerIndiceDeDevocionais().then((_) {
      if (mounted) setState(() {});
    });
  }
```

Na árvore de widgets do `build`, entre o bloco "Em quantos dias?" e o bloco "Prévia":

```dart
              const SizedBox(height: Spacing.sp20),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Incluir devocionais dos livros'),
                subtitle: const Text(
                  'Junto de cada capítulo, os devocionais de Manhã, Noite e '
                  'Promessas de Deus que citam aquele texto.',
                ),
                value: _incluirDevocionais,
                onChanged: (marcado) =>
                    setState(() => _incluirDevocionais = marcado ?? false),
              ),
              if (_incluirDevocionais) ...[
                const SizedBox(height: Spacing.sp8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Antes do capítulo')),
                    ButtonSegment(value: false, label: Text('Depois do capítulo')),
                  ],
                  selected: {_devocionalAntes},
                  onSelectionChanged: (novo) =>
                      setState(() => _devocionalAntes = novo.first),
                ),
              ],
```

- [ ] **Step 4: Rodar e verificar que passa**

Run: `fvm flutter test test/planos_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/telas/novo_plano.dart test/planos_test.dart
git commit -m "TelaNovoPlano ganha checkbox e seletor de devocionais"
```

---

### Task 8: Verificação final, documentação e versão

**Files:**
- Modify: `README.md`, `PRODUCT.md`
- Modify: `pubspec.yaml`

**Interfaces:** nenhuma nova — só fechamento.

- [ ] **Step 1: Rodar a suíte completa**

Run: `fvm flutter analyze && fvm flutter test`
Expected: 0 issues, todos os testes passam (os já existentes e os das Tasks 1-7).

- [ ] **Step 2: Documentar a feature**

Em `PRODUCT.md`, na seção de planos de leitura (ou "Capabilities", seguindo o padrão de outras features já documentadas ali), acrescentar uma entrada descrevendo: ao criar um plano do usuário, é possível incluir os devocionais (Manhã, Noite, Promessas) cujos versículos citados caem nos capítulos do plano, antes ou depois de cada capítulo.

Em `README.md`, acrescentar uma entrada datada (padrão já usado no arquivo, ex. "31/08/2026") descrevendo a implementação: índice livro+capítulo → devocionais em `Conteudo`, `ItemDoDia` (capítulo ou devocional) em `DiaDePlanoDoUsuario`, checkbox + seletor antes/depois em `TelaNovoPlano`.

- [ ] **Step 3: Bumpar o build number**

Em `pubspec.yaml`, incrementar só o `N` de `version: X.Y.Z+N`.

- [ ] **Step 4: Commit final**

```bash
git add README.md PRODUCT.md pubspec.yaml
git commit -m "Documenta devocionais nos planos de leitura e bumpa versão"
```
