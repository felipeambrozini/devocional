import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../estilo/espacamento.dart';
import '../funcoes/datas.dart';
import 'botao.dart';
import 'botao_de_conta.dart';

/// Bom dia, boa tarde ou boa noite, só para a saudação — separado de
/// `Periodo`, que decide qual devocional (Manhã ou Noite) aparece na
/// prévia. O conteúdo é binário porque Spurgeon só escreveu duas partes por
/// dia; a saudação não precisa seguir a mesma régua.
String _saudacaoPelaHora(int hora) {
  if (hora < 6) return 'Boa noite';
  if (hora < 12) return 'Bom dia';
  if (hora < 18) return 'Boa tarde';
  return 'Boa noite';
}

class TabernaculoCabecalhoDaHoje extends StatelessWidget {
  const TabernaculoCabecalhoDaHoje({super.key, required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final saudacao = _saudacaoPelaHora(data.hour);

    return ListenableBuilder(
      listenable: Nuvem.instancia,
      builder: (context, _) {
        final nuvem = Nuvem.instancia;
        final nome = nuvem.primeiroNome;
        return Row(
          children: [
            if (nuvem.logado) ...[
              // A foto do Google quando há, senão a inicial do nome, sem
              // upload. O toque abre o perfil, onde moram o Sair e o resto da
              // conta. Com 60px de diâmetro, já passa dos 48 do alvo mínimo.
              Semantics(
                container: true,
                button: true,
                label: 'Abrir perfil',
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.push('/perfil'),
                    child: ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: nuvem.fotoUrl != null
                            ? NetworkImage(nuvem.fotoUrl!)
                            : null,
                        child: nuvem.fotoUrl == null
                            ? Text(
                                (nome ?? '?').substring(0, 1).toUpperCase(),
                                style: tema.headlineMedium?.copyWith(
                                  color: cor.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TabernaculoEspacamento.sp14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      nome != null ? '$saudacao, $nome' : saudacao,
                      style: tema.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: TabernaculoEspacamento.sp4),
                  Text(dataLonga(data), style: tema.bodySmall),
                ],
              ),
            ),
            // Entrar na conta, no fim do cabeçalho: o convite mora aqui (e
            // não na folha de ajustes), porque o estado da conta muda a
            // saudação ao lado. Logado, não mostra nada.
            const TabernaculoBotaoDeConta(),
            // Hoje não tem AppBar onde pendurar a ação, e sem isto os ajustes
            // só seriam alcançáveis de duas das seis abas.
            TabernaculoBotaoDeAjustes(estado: EscopoDoEstado.de(context)),
          ],
        );
      },
    );
  }
}
