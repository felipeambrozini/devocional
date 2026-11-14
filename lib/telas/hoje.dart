import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../dados/estado.dart';
import '../dados/biblioteca.dart';
import '../dados/config_admin.dart';
import '../dados/modelos.dart';
import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';
import 'devocional.dart';

/// Tela de abertura: quem sou, o devocional da hora, a leitura do dia e o progresso.
class TelaHoje extends StatefulWidget {
  const TelaHoje({super.key});

  @override
  State<TelaHoje> createState() => _TelaHojeState();
}

class _TelaHojeState extends State<TelaHoje> {
  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final estado = EscopoDoEstado.de(context);
    final periodo = Periodo.pelaHora(agora.hour);
    final livrosEmLeitura = [
      for (final slug in estado.leituraDeLivros.livrosEmLeitura)
        ?obraPorSlug(slug),
    ];

    return Scaffold(
      body: SafeArea(
        child: DevocionalLarguraDeLeitura(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              ConfigAdmin.instancia,
              Nuvem.instancia,
            ]),
            builder: (context, _) {
              // A leitura da hora pode estar desligada no painel: aí o
              // destaque cai para a outra leitura do período que continuar
              // ligada, e some se as duas estiverem fora do ar. Promessas tem
              // o próprio cartão, que some junto quando desligada.
              final leituraDaHora = periodo == Periodo.manha
                  ? Leitura.manha
                  : Leitura.noite;
              final leituraEmDestaque = leituraAtiva(leituraDaHora)
                  ? leituraDaHora
                  : leituraAtiva(Leitura.manha)
                  ? Leitura.manha
                  : leituraAtiva(Leitura.noite)
                  ? Leitura.noite
                  : null;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  DevocionalEspacamento.sp16,
                  DevocionalEspacamento.sp8,
                  DevocionalEspacamento.sp16,
                  DevocionalEspacamento.sp32,
                ),
                children: [
                  DevocionalCabecalhoDaHoje(data: agora),
                  const SizedBox(height: DevocionalEspacamento.sp20),
                  // Ajuda só para quem chega: um cartão curto na primeira visita,
                  // que some para sempre com "Entendi". Fica antes dos cards de
                  // leitura, para orientar quem não conhece o app antes de mostrar
                  // o conteúdo do dia.
                  if (!estado.ajudaDispensada) ...[
                    DevocionalCartaoDeAjuda(estado: estado),
                    const SizedBox(height: DevocionalEspacamento.sp16),
                  ],
                  // A leitura do plano abre a tela, antes dos devocionais: é a
                  // razão do app existir. A leitura da hora vem logo depois, no
                  // cartão que ganha o filete; promessas mantém o cartão sem ele,
                  // e o progresso do ano segue a leitura como quem a acompanha.
                  DevocionalLeituraDeHoje(data: agora),
                  // Planos personalizados em andamento: o próximo dia de cada
                  // um, entre a leitura do cronograma e os devocionais.
                  if (Recursos.planos) ...[
                    const SizedBox(height: DevocionalEspacamento.sp16),
                    DevocionalPlanosEmAndamento(estado: estado),
                  ],
                  if (leituraEmDestaque != null) ...[
                    const SizedBox(height: DevocionalEspacamento.sp16),
                    DevocionalPreviaDaLeitura(
                      data: agora,
                      leitura: leituraEmDestaque,
                      destaque: true,
                    ),
                  ],
                  if (Recursos.promessas) ...[
                    const SizedBox(height: DevocionalEspacamento.sp16),
                    DevocionalPreviaDaLeitura(
                      data: agora,
                      leitura: Leitura.promessas,
                    ),
                  ],
                  // Os livros que o usuário começou a ler: nenhum, não mostra
                  // nada; um, o cartão; mais de um, uma lista horizontal. A
                  // estante inteira fica na aba Biblioteca.
                  if (Recursos.biblioteca && livrosEmLeitura.isNotEmpty) ...[
                    const SizedBox(height: DevocionalEspacamento.sp16),
                    DevocionalLivrosEmLeitura(
                      obras: livrosEmLeitura,
                      aoAbrir: (obra) {
                        final capitulo =
                            estado.leituraDeLivros
                                .posicaoDe(obra.slug)
                                ?.capitulo ??
                            0;
                        context.go('/biblioteca/${obra.slug}/${capitulo + 1}');
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
