import 'package:flutter/material.dart';

import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/recursos.dart';
import 'carrega_uma_vez.dart';
import 'cartao_leitura_progresso.dart';
import 'cartao_leitura_progresso_carregando.dart';
import 'cartao_leitura_progresso_erro.dart';

class DevocionalLeituraDeHoje extends StatelessWidget {
  const DevocionalLeituraDeHoje({super.key, required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    // Com o cronograma desligado no painel, o cartão some junto — mesmo
    // padrão do BotaoDeVoz com `ouvirTextos`. A Hoje já ouve o ConfigAdmin
    // (ver TelaHoje), então desligar reflete na hora, sem trocar de tela.
    if (!Recursos.cronograma) return const SizedBox.shrink();
    final estado = EscopoDoEstado.de(context);
    return DevocionalCarregaUmaVez<DiaDoPlano?>(
      chave: Conteudo.chaveDoDia(data),
      carregar: () => Conteudo.instancia.diaDoPlano(data),
      construir: (context, snap) {
        if (snap.hasError) {
          return DevocionalCartaoLeituraProgressoErro(
            mensagem: 'Não foi possível carregar o cronograma.',
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const DevocionalCartaoLeituraProgressoCarregando();
        }
        final dia = snap.data!;
        return DevocionalCartaoLeituraProgresso(
          dia: dia,
          estado: estado,
          ano: data.year,
        );
      },
    );
  }
}
