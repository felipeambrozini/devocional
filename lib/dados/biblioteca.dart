import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'modelos.dart';
import 'registro.dart';

/// Os livros de Spurgeon que o app traz, na ordem em que foram publicados em
/// inglês (a estante mostra nesta ordem). Cada slug tem o texto em
/// `assets/livros/<slug>.json` (ver `tools/biblioteca/livro.py`). Um livro só
/// entra aqui depois de traduzido e auditado por inteiro: a estante não mostra
/// livro pela metade.
const obrasDaBiblioteca = [
  ObraDaBiblioteca(
    slug: 'o_santo_e_o_seu_salvador',
    titulo: 'O Santo e o Seu Salvador',
    subtitulo: 'O progresso da alma no conhecimento de Jesus',
    capa: 'assets/imagens/capa_o_santo_e_o_seu_salvador.webp',
  ),
  ObraDaBiblioteca(
    slug: 'tesouro_de_davi',
    titulo: 'Tesouro de Davi',
    subtitulo: 'Spurgeon sobre os Salmos, um capítulo por salmo',
    capa: 'assets/imagens/capa_tesouro_de_davi.webp',
  ),
  ObraDaBiblioteca(
    slug: 'conversas_de_joao_lavrador',
    titulo: 'Conversas de João Lavrador',
    subtitulo: 'Conselhos simples para gente simples',
    capa: 'assets/imagens/capa_conversas_de_joao_lavrador.webp',
  ),
  ObraDaBiblioteca(
    slug: 'licoes_aos_meus_alunos',
    titulo: 'Lições aos Meus Alunos',
    subtitulo: 'Para ministros e pregadores',
    capa: 'assets/imagens/capa_licoes_aos_meus_alunos.webp',
  ),
  ObraDaBiblioteca(
    slug: 'retratos_de_joao_lavrador',
    titulo: 'Retratos de João Lavrador',
    subtitulo: 'Mais conselhos simples para gente simples',
    capa: 'assets/imagens/capa_retratos_de_joao_lavrador.webp',
  ),
  ObraDaBiblioteca(
    slug: 'alfabeto_de_ouro',
    titulo: 'Alfabeto de Ouro',
    subtitulo: 'Comentário devocional ao Salmo 119, letra por letra',
    capa: 'assets/imagens/capa_alfabeto_de_ouro.webp',
  ),
  ObraDaBiblioteca(
    slug: 'ao_redor_do_portao_estreito',
    titulo: 'Ao Redor do Portão Estreito',
    subtitulo: 'Uma conversa amiga com quem busca a salvação',
    capa: 'assets/imagens/capa_ao_redor_do_portao_estreito.webp',
  ),
  ObraDaBiblioteca(
    slug: 'somente_pela_graca',
    titulo: 'Somente pela Graça',
    subtitulo:
        'Uma palavra sincera a quem busca a salvação pelo Senhor Jesus Cristo',
    capa: 'assets/imagens/capa_somente_pela_graca.webp',
  ),
  ObraDaBiblioteca(
    slug: 'segundo_a_promessa',
    titulo: 'Segundo a Promessa',
    subtitulo: 'O modo do Senhor tratar o seu povo escolhido',
    capa: 'assets/imagens/capa_segundo_a_promessa.webp',
  ),
  ObraDaBiblioteca(
    slug: 'o_maior_combate_do_mundo',
    titulo: 'O Maior Combate do Mundo',
    subtitulo: 'A última conferência de Spurgeon aos pastores',
    capa: 'assets/imagens/capa_o_maior_combate_do_mundo.webp',
  ),
  ObraDaBiblioteca(
    slug: 'o_evangelho_do_reino',
    titulo: 'O Evangelho do Reino',
    subtitulo: 'Uma exposição popular do Evangelho de Mateus',
    capa: 'assets/imagens/capa_o_evangelho_do_reino.webp',
  ),
  ObraDaBiblioteca(
    slug: 'o_ganhador_de_almas',
    titulo: 'O Ganhador de Almas',
    subtitulo: 'Como conduzir os pecadores ao Salvador',
    capa: 'assets/imagens/capa_o_ganhador_de_almas.webp',
  ),
  ObraDaBiblioteca(
    slug: 'pescadores_de_criancas',
    titulo: 'Pescadores de Crianças',
    subtitulo: 'Para pais e mestres',
    capa: 'assets/imagens/capa_pescadores_de_criancas.webp',
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
