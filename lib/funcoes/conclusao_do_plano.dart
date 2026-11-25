import '../dados/estado.dart';
import '../dados/planos.dart';

/// Se todos os dias de [plano] estão marcados como lidos neste aparelho.
///
/// Os três caminhos que marcam um dia de plano (o toque na tela do plano, o
/// toque no cartão da Hoje e a marcação ao chegar ao fim da leitura) passam
/// por aqui depois de marcar, para o fim do plano ser notado em todos eles.
bool planoConcluido(Estado estado, PlanoDoUsuario plano) {
  final dias = plano.diasDoPlano;
  return dias.isNotEmpty &&
      dias.every((dia) => estado.foiLidoNoPlano(plano.id, dia.numero));
}

/// O aviso discreto do fim de um plano: sem streak nem comemoração, só o
/// ponto de chegada (Princípio 1 do PRODUCT.md).
String avisoDePlanoConcluido(PlanoDoUsuario plano) =>
    'Você concluiu o plano ${plano.titulo}';
