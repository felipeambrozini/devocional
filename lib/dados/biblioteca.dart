import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'modelos.dart';
import 'registro.dart';

/// Os livros de Spurgeon que o app traz. Cada slug tem o texto em
/// `assets/livros/<slug>.json` (ver `tools/biblioteca/livro.py`). Um livro só
/// entra aqui depois de traduzido e auditado por inteiro: a estante não mostra
/// livro pela metade.
const obrasDaBiblioteca = [
  ObraDaBiblioteca(
    slug: 'somente_pela_graca',
    titulo: 'Somente pela Graça',
    subtitulo:
        'Uma palavra sincera a quem busca a salvação pelo Senhor Jesus Cristo',
    capa: 'assets/imagens/capa_somente_pela_graca.webp',
  ),
  ObraDaBiblioteca(
    slug: 'alfabeto_de_ouro',
    titulo: 'Alfabeto de Ouro',
    subtitulo: 'Comentário devocional ao Salmo 119, letra por letra',
    capa: 'assets/imagens/capa_alfabeto_de_ouro.webp',
  ),
];

ObraDaBiblioteca? obraPorSlug(String slug) {
  for (final obra in obrasDaBiblioteca) {
    if (obra.slug == slug) return obra;
  }
  return null;
}

/// Carrega e guarda em memória os capítulos de cada livro, uma leitura do
/// asset por livro.
class Biblioteca {
  Biblioteca._();

  static final instancia = Biblioteca._();

  final Map<String, List<CapituloDoLivro>> _livros = {};

  /// Marcado só depois do `await`, no `finally`: uma segunda chamada
  /// concorrente paga outra leitura do asset em vez de receber `null` de um
  /// livro que ainda está carregando (mesma regra de `Conteudo`).
  final Map<String, bool> _tentou = {};

  /// Os capítulos do livro, ou `null` se o asset não existe ou está quebrado.
  Future<List<CapituloDoLivro>?> capitulos(String slug) async {
    final guardado = _livros[slug];
    if (guardado != null) return guardado;
    if (_tentou[slug] == true) return null;
    try {
      final cru = await rootBundle.loadString('assets/livros/$slug.json');
      final dados = json.decode(cru) as Map<String, dynamic>;
      return _livros[slug] = [
        for (final c in dados['capitulos'] as List)
          CapituloDoLivro.doJson(c as Map<String, dynamic>),
      ];
    } catch (erro, pilha) {
      Registro.erro('Biblioteca.capitulos($slug)', erro, pilha);
      return null;
    } finally {
      _tentou[slug] = true;
    }
  }
}
