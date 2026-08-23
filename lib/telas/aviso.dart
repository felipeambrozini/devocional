import 'package:flutter/material.dart';

/// Avisos e confirmações compartilhados: a snackbar com fechamento próprio e o
/// diálogo de confirmação destrutiva. Um lugar só para o comportamento ser o
/// mesmo em toda parte.

/// Divulgação de que o chat responde por inteligência artificial. O mesmo
/// texto em todo lugar em que uma IA fala: rodapé do chat, boas-vindas e
/// histórico vazio — repetir é o que o torna um aviso, não um enfeite.
const avisoDeIa = 'Respostas geradas por inteligência artificial';

/// Quanto tempo um aviso de snackbar fica na tela antes de fechar sozinho. Um
/// valor só em todo o projeto: se a duração mudar um dia, muda aqui.
const duracaoDeAviso = Duration(seconds: 3);

/// Mostra um aviso na snackbar e o fecha sozinho depois de [duracaoDeAviso].
///
/// O ScaffoldMessenger tem um timer próprio para isso, mas ele nunca nasce
/// quando o SnackBar tem ação (bug do Flutter 3.44.9, reproduzido em teste):
/// um "Desfazer" ou um "Tentar de novo" deixava o aviso na tela para sempre.
/// Então o fechamento sai daqui, e o `closed` do aviso garante que um fechar
/// tardio não leva junto um aviso mais novo mostrado no meio do caminho.
///
/// Quem mostra um aviso sempre passa por aqui: assim a duração é uma só, a de
/// [duracaoDeAviso], e o comportamento é o mesmo em toda parte.
void mostrarAviso(
  BuildContext context,
  String texto, {
  String? rotuloDeAcao,
  VoidCallback? aoAgir,
}) => mostrarAvisoNo(
  ScaffoldMessenger.of(context),
  texto,
  rotuloDeAcao: rotuloDeAcao,
  aoAgir: aoAgir,
);

/// O mesmo que [mostrarAviso], mas com o messenger já em mãos — o caso das
/// telas que capturam o messenger antes de um `await` e só mostram o aviso
/// depois, quando o contexto pode não estar mais montado.
void mostrarAvisoNo(
  ScaffoldMessengerState mensageiro,
  String texto, {
  String? rotuloDeAcao,
  VoidCallback? aoAgir,
}) {
  mensageiro.hideCurrentSnackBar();
  final aviso = mensageiro.showSnackBar(
    SnackBar(
      content: Text(texto),
      duration: duracaoDeAviso,
      action: rotuloDeAcao == null
          ? null
          : SnackBarAction(
              label: rotuloDeAcao,
              onPressed: () {
                aoAgir?.call();
                mensageiro.hideCurrentSnackBar();
              },
            ),
    ),
  );
  var fechou = false;
  aviso.closed.whenComplete(() => fechou = true);
  Future<void>.delayed(duracaoDeAviso, () {
    if (!fechou) {
      mensageiro.hideCurrentSnackBar();
    }
  });
}

/// Diálogo de confirmação de ação destrutiva: "Cancelar" devolve false,
/// [rotuloDaAcao] devolve true. O esqueleto é um só para todas as confirmações
/// do app; os textos e o rótulo da ação são de quem chama.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String conteudo,
  required String rotuloDaAcao,
}) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(conteudo),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(rotuloDaAcao),
        ),
      ],
    ),
  );
  return confirmou ?? false;
}
