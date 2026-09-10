import 'package:flutter/foundation.dart';

import '../dados/voz.dart';

/// Estado da tela Sobre: só a contagem de tentativas da demonstração de voz.
class SobreControlador extends ChangeNotifier {
  /// Quantas vezes a demonstração foi pedida de novo depois de um erro: a
  /// chave do [DevocionalCarregaUmaVez] muda a cada tentativa, e é assim que
  /// ele recarrega sem reabrir a tela.
  int tentativasDaDemo = 0;

  void tentarDeNovo() {
    tentativasDaDemo++;
    notifyListeners();
  }

  @override
  void dispose() {
    // A pílula da demonstração sai da tela com ela: a regra de não deixar um
    // áudio tocando sem o botão de parar à vista vale aqui também.
    Voz.instancia.parar();
    super.dispose();
  }
}
