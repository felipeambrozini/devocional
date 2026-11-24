import 'package:material_ui/material_ui.dart';

import '../dados/estado.dart';
import '../dados/modelos.dart';
import 'aviso.dart';

/// Pergunta e termina a leitura de [obra]: o livro é dado como lido, a
/// posição e os capítulos marcados voltam ao zero e a contagem de leituras
/// sobe (ver `LeituraDeLivros.concluir`). Pede confirmação porque zera o
/// progresso, e um toque ou deslize acidental não pode custar os capítulos
/// marcados.
///
/// Um fluxo só para o botão do último capítulo e o do sumário do livro, para
/// os dois dizerem e fazerem a mesma coisa. [antesDeConcluir] roda depois da
/// confirmação e antes de zerar: o capítulo aberto usa para parar de gravar a
/// posição, que senão reapareceria por cima do recomeço.
///
/// Devolve `true` se a leitura foi terminada.
Future<bool> terminarLeituraDoLivro(
  BuildContext context,
  Estado estado,
  ObraDaBiblioteca obra, {
  VoidCallback? antesDeConcluir,
}) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Terminar a leitura?',
    conteudo:
        '${obra.titulo} será dado como lido e a leitura recomeça do '
        'primeiro capítulo. Seus favoritos e notas continuam guardados.',
    rotuloDaAcao: 'Terminar',
  );
  if (!confirmou || !context.mounted) return false;
  final mensageiro = ScaffoldMessenger.of(context);
  antesDeConcluir?.call();
  await estado.leituraDeLivros.concluir(obra.slug);
  mostrarAvisoNo(
    mensageiro,
    'Você terminou ${obra.titulo}. Ao abrir o livro de novo, a leitura '
    'recomeça do primeiro capítulo.',
  );
  return true;
}
