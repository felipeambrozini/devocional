import 'package:material_ui/material_ui.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';

/// O retrato de uma persona num anel do metal — a gramática única dos três
/// pontos que mostram quem fala: as entradas de conversa (a carta da aba
/// Conversas e o topo do histórico) e o botão de voz da leitura. Anel de 1,5
/// na cor primária, folga entre o anel e a foto, e o corte alinhado ao topo
/// que preserva o cabelo (a foto é mais alta que larga). Sem o asset, a
/// inicial ocupa o lugar.
///
/// Sem [anel], é a foto pequena que acompanha a fala: ao lado de cada
/// resposta no chat e no título da barra do chat e do histórico.
class DevocionalRetratoDePersona extends StatelessWidget {
  const DevocionalRetratoDePersona({
    super.key,
    required this.persona,
    this.tamanho = 38,
    this.folga = DevocionalEspacamento.sp2,
    this.decorativo = false,
    this.anel = true,
    this.espessuraDoAnel = 1.5,
  });

  final Persona persona;
  final double tamanho;

  /// A folga entre o anel dourado e a foto: sem ela a foto preenche o círculo
  /// até a borda e o cabelo encosta no aro. As entradas de conversa usam a
  /// apertada; o botão de voz usa [DevocionalEspacamento.sp4].
  final double folga;

  /// Dentro de um botão cujo rótulo já diz o que faz, a imagem é enfeite:
  /// fora da árvore de semântica para o leitor de tela não ler duas vezes.
  final bool decorativo;

  /// O aro do metal em volta. Sem ele, [folga] e [espessuraDoAnel] não valem.
  final bool anel;

  /// A boas-vindas, de retrato grande, usa um aro mais grosso.
  final double espessuraDoAnel;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final foto = ClipOval(
      child: Image.asset(
        persona.foto,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        excludeFromSemantics: decorativo,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => Container(
          color: cor.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Text(
            persona.nomeCurto.characters.first,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: cor.primary,
              fontSize: tamanho * 0.42,
            ),
          ),
        ),
      ),
    );
    if (!anel) return foto;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cor.primary, width: espessuraDoAnel),
      ),
      child: Padding(padding: EdgeInsets.all(folga), child: foto),
    );
  }
}
