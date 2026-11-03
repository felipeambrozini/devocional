import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/estado.dart';
import '../dados/config_admin.dart';
import '../dados/nuvem.dart';
import '../dados/planos.dart';
import '../dados/recursos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// A aba Meus Planos: a lista dos planos do usuário e o caminho para criar
/// um novo.
///
/// A aba fica visível para todo mundo, mas os planos só existem para quem tem
/// conta: sem ela, um aviso com o botão de entrar ocupa o lugar da lista. O
/// interruptor [Recursos.planoPersonalizado] desliga a aba inteira.
class DevocionalAbaDosMeusPlanos extends StatelessWidget {
  const DevocionalAbaDosMeusPlanos({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Nuvem.instancia, ConfigAdmin.instancia]),
      builder: (context, _) {
        if (!Recursos.planoPersonalizado) {
          return const DevocionalAvisoVazio(
            icone: FontAwesomeIcons.calendarPlus,
            titulo: 'Planos indisponíveis',
            detalhe:
                'Os planos de leitura personalizados estão desligados no '
                'momento. Tente de novo mais tarde.',
          );
        }
        if (!Nuvem.instancia.logado) {
          return const DevocionalCartaoDeEntrar(
            titulo: 'Entre para ver seus planos',
            descricao:
                'Os planos de leitura ficam guardados na sua conta. Entre '
                'para ler "A Vida de Jesus em 30 dias" e criar os seus.',
          );
        }
        return _ListaDePlanos(estado: EscopoDoEstado.de(context));
      },
    );
  }
}

class _ListaDePlanos extends StatelessWidget {
  const _ListaDePlanos({required this.estado});

  final Estado estado;

  @override
  Widget build(BuildContext context) {
    final planos = estado.planosParaExibir;

    return DevocionalLarguraDeLeitura(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          DevocionalEspacamento.sp16,
          DevocionalEspacamento.sp12,
          DevocionalEspacamento.sp16,
          DevocionalEspacamento.sp32,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Seus planos',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              DevocionalBotaoPrimario.icon(
                icon: const FaIcon(FontAwesomeIcons.plus),
                label: const Text('Criar plano'),
                onPressed: () => _abrirNovoPlano(context),
              ),
            ],
          ),
          const SizedBox(height: DevocionalEspacamento.sp12),
          for (final plano in planos) ...[
            DevocionalCartaoDePlano(plano: plano),
            const SizedBox(height: DevocionalEspacamento.sp10),
          ],
        ],
      ),
    );
  }

  // Rotas próprias sob /plano (ver main.dart), não Navigator.push avulso: é o
  // que faz a aba resetar para esta lista ao voltar de outra aba com um
  // plano aberto (Moldura._irParaAba).
  Future<void> _abrirNovoPlano(BuildContext context) async {
    final criado = await context.push<PlanoDoUsuario>('/plano/novo');
    if (criado == null || !context.mounted) return;
    context.push('/plano/${criado.id}');
  }
}
