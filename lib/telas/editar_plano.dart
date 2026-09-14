import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../dados/planos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
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
      return 'Informe em quantos dias o plano acontece.';
    }
    final total = totalDeCapitulos();
    if (total > 0 && numero > total) {
      return 'Os livros têm $total capítulos; o máximo é $total dias.';
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
            mostrarAviso(dialogContext, 'Escolha pelo menos um livro.');
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

        return AlertDialog(
          title: Text(
            'Editar plano',
            style: Theme.of(dialogContext).textTheme.headlineSmall,
          ),
          content: SizedBox(
            width: 420,
            height: 520,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mudouODiaADia()) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          DevocionalEspacamento.sp12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DevocionalFilete(largura: 48),
                            const SizedBox(height: DevocionalEspacamento.sp8),
                            Text(
                              'Mudar os livros ou os dias remonta o plano: o '
                              'progresso já marcado será apagado.',
                              style: Theme.of(
                                dialogContext,
                              ).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DevocionalEspacamento.sp16),
                    ],
                    TextField(
                      controller: titulo,
                      autofocus: !kIsWeb,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome do plano',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp20),
                    Text(
                      'Quais livros?',
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp8),
                    DevocionalBotaoSecundario.icon(
                      onPressed: escolherLivros,
                      icon: const FaIcon(FontAwesomeIcons.book),
                      label: Text(
                        '${livros.length} '
                        '${livros.length == 1 ? 'livro' : 'livros'} '
                        'escolhidos',
                      ),
                    ),
                    if (livros.isNotEmpty) ...[
                      const SizedBox(height: DevocionalEspacamento.sp10),
                      DevocionalLivrosEscolhidos(
                        livros: livros,
                        aoRemover: (slug) =>
                            setDialogState(() => livros.remove(slug)),
                        aoReordenar: (novaOrdem) => setDialogState(
                          () => livros
                            ..clear()
                            ..addAll(novaOrdem),
                        ),
                      ),
                    ],
                    const SizedBox(height: DevocionalEspacamento.sp20),
                    Text(
                      'Em quantos dias?',
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp8),
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
                            ? 'Escolha os livros para ver o tamanho do plano.'
                            : 'O plano terá ${totalDeCapitulos()} '
                                  '${totalDeCapitulos() == 1 ? 'capítulo' : 'capítulos'}.',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp20),
                    DevocionalOpcaoDeDevocionais(
                      incluir: incluirDevocionais,
                      antes: devocionalAntes,
                      aoMudarIncluir: (marcado) => setDialogState(
                        () => incluirDevocionais = marcado ?? false,
                      ),
                      aoMudarOrdem: (antes) =>
                          setDialogState(() => devocionalAntes = antes),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            DevocionalBotaoTerciario(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            DevocionalBotaoPrimario(
              onPressed: salvar,
              child: Text(mudouODiaADia() ? 'Mudar e reiniciar' : 'Salvar'),
            ),
          ],
        );
      },
    ),
  );
}
