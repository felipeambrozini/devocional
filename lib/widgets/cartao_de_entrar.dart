import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';
import 'botao_de_entrar.dart';
import 'layout_leitura.dart';

/// O caminho para entrar na conta — usado quando o plano foi aberto por link
/// e só participantes o veem, ou quando a aba Meus Planos depende de conta
/// para guardar planos próprios na nuvem (ver `titulo`/`descricao`).
class TabernaculoCartaoDeEntrar extends StatelessWidget {
  const TabernaculoCartaoDeEntrar({
    super.key,
    this.onEntrar,
    this.titulo = 'Este plano é compartilhado por link',
    this.descricao =
        'Entre com sua conta para participar, marcar os dias lidos '
        'e ver o progresso de todos.',
    this.embutido = false,
  });

  /// Roda depois do login. Opcional: quem só depende de `Nuvem` para
  /// reconstruir a tela não precisa de callback.
  final VoidCallback? onEntrar;
  final String titulo;
  final String descricao;

  /// Só o cartão, para quem já está dentro de uma lista que rola e dá o
  /// próprio espaçamento (a Hoje). Sem o centro, a rolagem própria e a
  /// margem da página inteira.
  final bool embutido;

  @override
  Widget build(BuildContext context) {
    final cartao = Card(
      child: Padding(
        padding: const EdgeInsets.all(TabernaculoEspacamento.sp20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Container: sem ele o cabeçalho engolia a descrição
            // abaixo, e o leitor de tela lia o parágrafo inteiro
            // como título.
            Semantics(
              container: true,
              header: true,
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: TabernaculoEspacamento.sp8),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: TabernaculoEspacamento.sp16),
            TabernaculoBotaoDeEntrar(aoEntrar: onEntrar),
          ],
        ),
      ),
    );
    if (embutido) return cartao;
    return TabernaculoLarguraDeLeitura(
      // Center + SingleChildScrollView: sem isto, um título/descrição mais
      // longos (ver o uso em aba_dos_meus_planos.dart) podem estourar a
      // altura disponível numa janela baixa, em vez de só rolar.
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(TabernaculoEspacamento.sp16),
            child: cartao,
          ),
        ),
      ),
    );
  }
}
