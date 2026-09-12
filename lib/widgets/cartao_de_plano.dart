import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../dados/planos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/planos_acoes.dart';
import '../widgets/widgets.dart';

/// Cartão de um plano na lista de Meus Planos: o que se lê, em quanto tempo
/// e o progresso. Tocar abre o plano; excluir e compartilhar vivem na tela
/// do plano.
class DevocionalCartaoDePlano extends StatelessWidget {
  const DevocionalCartaoDePlano({super.key, required this.plano});

  final PlanoDoUsuario plano;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);
    final dias = plano.diasDoPlano.length;
    final lidos = estado.diasLidosDoPlano(plano.id);
    // Sem criadoPor (plano local, ou o eco de um compartilhar ainda não
    // sincronizado) trata como criador: é sempre este aparelho que o criou.
    final souCriador =
        !plano.compartilhado ||
        plano.criadoPor == null ||
        plano.criadoPor == Nuvem.instancia.uid;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cor.outline.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/plano/${plano.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DevocionalEspacamento.sp14,
            DevocionalEspacamento.sp12,
            DevocionalEspacamento.sp8,
            DevocionalEspacamento.sp12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plano.titulo,
                      style: tema.titleMedium,
                    ),
                  ),
                  if (plano.compartilhado)
                    Padding(
                      padding: const EdgeInsets.only(top: DevocionalEspacamento.sp2),
                      child: Tooltip(
                        message: 'Plano compartilhado por link',
                        child: FaIcon(
                          FontAwesomeIcons.userGroup,
                          size: 18,
                          color: cor.primary,
                        ),
                      ),
                    ),
                  // Lixeira direto no cartão: excluir (ou sair, para quem só
                  // participa) não deveria exigir abrir o plano e achar o
                  // menu de três pontinhos lá dentro. Sem caixa encolhedora:
                  // o alvo de toque fica nos 48dp padrão do IconButton.
                  IconButton(
                    tooltip: souCriador ? 'Excluir plano' : 'Sair do plano',
                    icon: FaIcon(
                      FontAwesomeIcons.trash,
                      size: 20,
                      color: cor.onSurfaceVariant,
                    ),
                    onPressed: () => souCriador
                        ? excluirPlano(
                            context,
                            estado,
                            plano.id,
                            compartilhado: plano.compartilhado,
                          )
                        : sairDoPlano(context, estado, plano.id),
                  ),
                ],
              ),
              const SizedBox(height: DevocionalEspacamento.sp2),
              Text(
                listaDosLivros(plano.livros),
                style: tema.bodySmall?.copyWith(color: cor.onSurfaceVariant),
              ),
              Text(
                '${plano.dias} dias · ${plano.totalDeCapitulos} capítulos',
                style: tema.labelMedium?.copyWith(color: cor.onSurfaceVariant),
              ),
              const SizedBox(height: DevocionalEspacamento.sp10),
              Text(
                '$lidos de $dias dias lidos',
                style: tema.labelMedium,
              ),
              const SizedBox(height: DevocionalEspacamento.sp6),
              DevocionalProgressoFino(valor: dias == 0 ? 0 : lidos / dias),
            ],
          ),
        ),
      ),
    );
  }
}
