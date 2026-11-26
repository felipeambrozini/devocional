import 'package:material_ui/material_ui.dart';

import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import 'carrega_uma_vez.dart';
import 'cartao_leitura_progresso.dart';
import 'cartao_de_entrar.dart';
import 'cartao_leitura_progresso_aviso.dart';

class TabernaculoLeituraDeHoje extends StatelessWidget {
  const TabernaculoLeituraDeHoje({super.key, required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    // Com o cronograma desligado no painel, o cartão some junto — mesmo
    // padrão do BotaoDeVoz com `ouvirTextos`. A Hoje já ouve o ConfigAdmin
    // (ver TelaHoje), então desligar reflete na hora, sem trocar de tela.
    if (!Recursos.cronograma) return const SizedBox.shrink();
    // A leitura do dia vem do cronograma, que é pessoal: sem conta, o convite
    // ocupa o lugar. Na restauração da sessão não mostra nada, para o convite
    // não piscar para quem já está logado.
    return ListenableBuilder(
      listenable: Nuvem.instancia,
      builder: (context, _) {
        if (Nuvem.instancia.logado) return _leitura(context);
        if (Nuvem.instancia.carregandoConta) return const SizedBox.shrink();
        return const TabernaculoCartaoDeEntrar(
          embutido: true,
          titulo: 'Entre para ver o plano',
          descricao:
              'A leitura do dia vem do cronograma anual, guardado na sua '
              'conta.',
        );
      },
    );
  }

  Widget _leitura(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    return TabernaculoCarregaUmaVez<DiaDoPlano?>(
      chave: Conteudo.chaveDoDia(data),
      carregar: () => Conteudo.instancia.diaDoPlano(data),
      construir: (context, snap) {
        if (snap.hasError) {
          return const TabernaculoCartaoLeituraProgressoAviso(
            mensagem: 'Não foi possível carregar o cronograma',
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const TabernaculoCartaoLeituraProgressoAviso(
            mensagem: 'Carregando...',
          );
        }
        final dia = snap.data!;
        return TabernaculoCartaoLeituraProgresso(
          dia: dia,
          estado: estado,
          ano: data.year,
        );
      },
    );
  }
}
