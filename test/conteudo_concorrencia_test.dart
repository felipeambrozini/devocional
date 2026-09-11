import 'package:felipe_ambrozini/dados/conteudo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arquivo próprio de propósito: `Conteudo.instancia` é singleton e cacheia
/// para sempre a primeira tentativa de cada asset, então o teste precisa
/// rodar num processo fresco, antes de qualquer outro teste ter "esquentado"
/// o cache de Promessas de Deus (o `flutter test` roda cada arquivo em
/// isolamento próprio).
///
/// Reproduz o bug relatado: abrir a notificação de Promessas de Deus mostrava
/// "Não foi possível carregar" na primeira vez, mas funcionava ao trocar de
/// aba e voltar. A causa era `_carregarPromessas` marcar "já tentei" antes do
/// `await` terminar — a prévia da tela Hoje e a notificação pedem o mesmo
/// asset quase juntas na abertura do app, e a segunda chamada lia o cache
/// ainda vazio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'duas chamadas simultâneas a promessa() não perdem a que chega por último',
    () async {
      final data = DateTime(DateTime.now().year, 1, 1);

      // Sem aguardar a primeira: é exatamente a corrida entre a prévia da
      // tela Hoje e o deep link da notificação, as duas pedindo o mesmo dia
      // antes do asset terminar de carregar.
      final primeira = Conteudo.instancia.promessa(data);
      final segunda = Conteudo.instancia.promessa(data);

      final resultados = await Future.wait([primeira, segunda]);

      expect(
        resultados[0],
        isNotNull,
        reason: 'primeira chamada deveria carregar o dia normalmente',
      );
      expect(
        resultados[1],
        isNotNull,
        reason:
            'segunda chamada, feita antes do asset terminar de carregar, não '
            'pode devolver null só porque a primeira já está em andamento',
      );
    },
  );
}
