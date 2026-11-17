import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';
import 'botao_de_entrar.dart';
import 'layout_leitura.dart';

/// O caminho para entrar na conta — usado quando o plano foi aberto por link
/// e só participantes o veem, ou quando a aba Meus Planos depende de conta
/// para guardar planos próprios na nuvem (ver `titulo`/`descricao`).
class DevocionalCartaoDeEntrar extends StatelessWidget {
  const DevocionalCartaoDeEntrar({
    super.key,
    this.onEntrar,
    this.titulo = 'Este plano é compartilhado por link',
    this.descricao =
        'Entre com sua conta para participar, marcar os dias lidos '
        'e ver o progresso de todos.',
  });

  /// Roda depois do login. Opcional: quem só depende de `Nuvem` para
  /// reconstruir a tela não precisa de callback.
  final VoidCallback? onEntrar;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    return DevocionalLarguraDeLeitura(
      // Center + SingleChildScrollView: sem isto, um título/descrição mais
      // longos (ver o uso em aba_dos_meus_planos.dart) podem estourar a
      // altura disponível numa janela baixa, em vez de só rolar.
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(DevocionalEspacamento.sp20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        titulo,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp8),
                    Text(
                      descricao,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp16),
                    DevocionalBotaoDeEntrar(aoEntrar: onEntrar),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
