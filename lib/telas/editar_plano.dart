import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../dados/planos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/dialogos.dart';
import '../widgets/widgets.dart';
import 'novo_plano.dart' show mostrarSeletorDeLivros;

typedef EdicaoDePlano = ({
  String titulo,
  List<String> livros,
  int dias,
  bool incluirDevocionais,
  bool devocionalAntes,
});

/// Diálogo para editar um plano já criado: os mesmos campos de
/// `novo_plano.dart` (nome, livros, dias, devocionais), pré-preenchidos.
/// Devolve nulo se cancelado.
///
/// Mudar livros ou dias remonta os dias do plano — o dia 5 de hoje pode
/// virar outro trecho da Bíblia amanhã — então o próprio editor avisa com um
/// banner e o botão de salvar vira "Mudar e reiniciar" quando é o caso, em
/// vez de um diálogo de confirmação à parte.
Future<EdicaoDePlano?> mostrarEditorDePlano(
  BuildContext context,
  PlanoDoUsuario plano,
) {
  final titulo = TextEditingController(text: plano.titulo);
  final dias = TextEditingController(text: '${plano.dias}');
  final livros = [...plano.livros];
  var incluirDevocionais = plano.incluirDevocionais;
  var devocionalAntes = plano.devocionalAntes;
  final form = GlobalKey<FormState>();

  int totalDeCapitulos() {
    var total = 0;
    for (final slug in livros) {
      total += livroPorSlug(slug)?.capitulos ?? 0;
    }
    return total;
  }

  String? validarDias(String? valor) {
    final numero = int.tryParse(valor ?? '');
    if (numero == null || numero < 1) {
      return 'Informe em quantos dias o plano acontece';
    }
    final total = totalDeCapitulos();
    if (total > 0 && numero > total) {
      return 'Os livros têm $total capítulos; o máximo é $total dias';
    }
    return null;
  }

  return showDialog<EdicaoDePlano>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        // Mudar livros ou dias remonta os dias do plano — o dia 5 de hoje
        // pode virar outro trecho da Bíblia amanhã. Em vez de um terceiro
        // diálogo confirmando isso, o aviso mora no próprio editor e o botão
        // de salvar diz o que vai acontecer.
        bool mudouODiaADia() {
          final novoTotalDeDias = int.tryParse(dias.text);
          if (novoTotalDeDias == null) return false;
          return novoTotalDeDias != plano.dias ||
              livros.length != plano.livros.length ||
              !livros.asMap().entries.every(
                (e) => e.value == plano.livros[e.key],
              );
        }

        Future<void> escolherLivros() async {
          final escolhidos = await mostrarSeletorDeLivros(
            dialogContext,
            jaEscolhidos: livros,
          );
          if (escolhidos == null) return;
          setDialogState(() {
            livros
              ..clear()
              ..addAll(escolhidos);
          });
        }

        Future<void> salvar() async {
          if (livros.isEmpty) {
            mostrarAviso(dialogContext, 'Escolha pelo menos um livro');
            return;
          }
          if (!(form.currentState?.validate() ?? false)) return;
          final novoTotalDeDias = int.parse(dias.text);
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext, (
            titulo: titulo.text,
            livros: List<String>.from(livros),
            dias: novoTotalDeDias,
            incluirDevocionais: incluirDevocionais,
            devocionalAntes: devocionalAntes,
          ));
        }

        // Os campos são os mesmos na janela e na tela cheia: só o
        // invólucro muda com a largura.
        Widget campos() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mudouODiaADia()) ...[
                // Região viva: o banner aparece enquanto a pessoa mexe nos
                // livros ou dias, e o leitor de tela anuncia a consequência
                // antes de ela chegar ao botão de salvar.
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(TabernaculoEspacamento.sp12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TabernaculoFilete(largura: 48),
                        const SizedBox(height: TabernaculoEspacamento.sp8),
                        // bodyMedium, não bodySmall: é a consequência da
                        // edição, e precisa ser lida antes de salvar.
                        Text(
                          plano.compartilhado
                              ? 'Mudar os livros ou os dias remonta o plano: o '
                                    'progresso de todos os participantes '
                                    'recomeça do zero.'
                              : 'Mudar os livros ou os dias remonta o plano: o '
                                    'progresso já marcado será apagado.',
                          style: Theme.of(dialogContext).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: TabernaculoEspacamento.sp16),
              ],
              TextField(
                controller: titulo,
                autofocus: !kIsWeb,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome do plano'),
              ),
              const SizedBox(height: TabernaculoEspacamento.sp20),
              Text(
                'Quais livros?',
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: TabernaculoEspacamento.sp8),
              TabernaculoBotaoSecundario.icon(
                onPressed: escolherLivros,
                icon: const FaIcon(FontAwesomeIcons.book),
                label: Text(
                  '${livros.length} '
                  '${livros.length == 1 ? 'livro' : 'livros'} '
                  'escolhidos',
                ),
              ),
              if (livros.isNotEmpty) ...[
                const SizedBox(height: TabernaculoEspacamento.sp10),
                TabernaculoLivrosEscolhidos(
                  livros: livros,
                  aoRemover: (slug) =>
                      setDialogState(() => livros.remove(slug)),
                  aoReordenar: (novaOrdem) => setDialogState(
                    () => livros
                      ..clear()
                      ..addAll(novaOrdem),
                  ),
                  aoRestaurar: (slugs, indice) => setDialogState(() {
                    var ponto = indice;
                    if (ponto < 0) ponto = 0;
                    if (ponto > livros.length) ponto = livros.length;
                    for (final slug in slugs) {
                      if (!livros.contains(slug)) {
                        livros.insert(ponto, slug);
                        ponto++;
                      }
                    }
                  }),
                ),
              ],
              const SizedBox(height: TabernaculoEspacamento.sp20),
              Text(
                'Em quantos dias?',
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: TabernaculoEspacamento.sp8),
              TextFormField(
                controller: dias,
                keyboardType: TextInputType.number,
                onChanged: (_) => setDialogState(() {}),
                validator: validarDias,
                // Igual ao novo plano: o erro aparece enquanto digita,
                // não só ao tocar "Mudar e reiniciar".
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  helperText: totalDeCapitulos() == 0
                      ? 'Escolha os livros para ver o tamanho do plano'
                      : 'O plano terá ${totalDeCapitulos()} '
                            '${totalDeCapitulos() == 1 ? 'capítulo' : 'capítulos'}',
                ),
              ),
              const SizedBox(height: TabernaculoEspacamento.sp20),
              TabernaculoOpcaoDeDevocionais(
                incluir: incluirDevocionais,
                antes: devocionalAntes,
                aoMudarIncluir: (marcado) =>
                    setDialogState(() => incluirDevocionais = marcado ?? false),
                aoMudarOrdem: (antes) =>
                    setDialogState(() => devocionalAntes = antes),
              ),
            ],
          );
        }

        final acaoSalvar = TabernaculoBotaoPrimario(
          onPressed: salvar,
          child: Text(mudouODiaADia() ? 'Mudar e reiniciar' : 'Salvar'),
        );

        // Em celular a janela fixa espremia nome e dias sob o banner com o
        // teclado aberto: vira tela cheia, e voltar fecha sem salvar (o
        // mesmo que Cancelar).
        if (MediaQuery.sizeOf(dialogContext).width < 600) {
          return Dialog.fullscreen(
            child: Scaffold(
              appBar: const TabernaculoAppBar(title: Text('Editar plano')),
              body: Form(
                key: form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    TabernaculoEspacamento.sp16,
                    TabernaculoEspacamento.sp12,
                    TabernaculoEspacamento.sp16,
                    TabernaculoEspacamento.sp32,
                  ),
                  child: campos(),
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TabernaculoEspacamento.sp16,
                    TabernaculoEspacamento.sp8,
                    TabernaculoEspacamento.sp16,
                    TabernaculoEspacamento.sp16,
                  ),
                  child: SizedBox(width: double.infinity, child: acaoSalvar),
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: Text(
            'Editar plano',
            style: Theme.of(dialogContext).textTheme.headlineSmall,
          ),
          content: SizedBox(
            width: larguraDeDialogo(dialogContext, 420),
            child: Form(
              key: form,
              child: SingleChildScrollView(child: campos()),
            ),
          ),
          actions: [
            TabernaculoBotaoTerciario(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            acaoSalvar,
          ],
        );
      },
    ),
  );
}
