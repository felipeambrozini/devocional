import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../dados/planos.dart';
import '../dados/recursos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// A aba Meus Planos: a lista dos planos do usuário e o caminho para criar
/// um novo.
///
/// A aba fica visível para todo mundo — só o conteúdo muda com a conta e com
/// [Recursos.planoPersonalizado], mesma filosofia de gating de `conversas.dart`:
/// explicar o que falta e como pedir, nunca esconder a aba em silêncio.
class DevocionalAbaDosMeusPlanos extends StatelessWidget {
  const DevocionalAbaDosMeusPlanos({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Nuvem.instancia,
      builder: (context, _) {
        if (!Nuvem.instancia.logado) {
          return DevocionalCartaoDeEntrar(
            titulo: 'Seus próprios planos de leitura',
            descricao:
                'Entre com sua conta para criar, compartilhar e acompanhar '
                'planos de leitura próprios.',
            onEntrar: () {},
          );
        }
        if (!Recursos.planoPersonalizado) {
          return const DevocionalCartaoDePedirAcesso(
            icone: FontAwesomeIcons.calendarPlus,
            descricao:
                'Planos de leitura personalizados são um recurso premium. '
                'Fale comigo pelo WhatsApp para habilitar o acesso na sua '
                'conta.',
            mensagemDoWhatsapp:
                'Oi Felipe, quero habilitar planos personalizados',
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
    final planos = estado.planosDoUsuario;

    return DevocionalLarguraDeLeitura(
      child: planos.isEmpty
          ? DevocionalAvisoVazio(
              icone: FontAwesomeIcons.calendarDays,
              titulo: 'Nenhum plano de leitura ainda',
              detalhe:
                  'Escolha um ou mais livros e em quantos dias quer lê-los: '
                  'o plano se monta sozinho, dia por dia.',
              acao: DevocionalBotaoPrimario.icon(
                icon: const FaIcon(FontAwesomeIcons.plus),
                label: const Text('Criar plano'),
                onPressed: () => _abrirNovoPlano(context),
              ),
            )
          : ListView(
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
