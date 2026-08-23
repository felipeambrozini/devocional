import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/nuvem.dart';
import '../data/recursos.dart';
import '../data/voz.dart';
import '../spacing.dart';
import 'comuns.dart';

/// Créditos das traduções, da fonte dos devocionais e o link dos canais.
class TelaSobre extends StatefulWidget {
  const TelaSobre({super.key});

  @override
  State<TelaSobre> createState() => _TelaSobreState();
}

class _TelaSobreState extends State<TelaSobre> {
  /// Quantas vezes a demonstração foi pedida de novo depois de um erro: a
  /// chave do [CarregaUmaVez] muda a cada tentativa, e é assim que ele
  /// recarrega sem reabrir a tela.
  int _tentativasDaDemo = 0;

  @override
  void dispose() {
    // A pílula da demonstração sai da tela com ela: a regra de não deixar um
    // áudio tocando sem o botão de parar à vista vale aqui também.
    Voz.instancia.parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre'),
        actions: [
          IconButton(
            tooltip: 'Tamanho do texto e aparência',
            icon: const Icon(Icons.tune),
            onPressed: () =>
                ajustesDeLeitura(context, EscopoDoEstado.de(context)),
          ),
          // A demonstração vive num ListView: quem rola até a ajuda não vê
          // mais a pílula, e o trecho não pode tocar sem o botão de parar à
          // vista. O indicador também cobre o trecho pausado (chamada).
          const IndicadorDeVozNaBarra(chave: 'trecho:salmos.1'),
        ],
      ),
      body: LarguraDeLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sp20,
            Spacing.sp16,
            Spacing.sp20,
            Spacing.sp40,
          ),
          children: [
            Text('Devocional', style: tema.displayMedium),
            const SizedBox(height: Spacing.sp8),
            const Filete(largura: 64),
            const SizedBox(height: Spacing.sp12),
            // A versão pequena, sem alarde, é o que basta para quem quer
            // conferir se está na última compilação.
            CarregaUmaVez<String>(
              chave: 'versao',
              carregar: () async => (await PackageInfo.fromPlatform()).version,
              construir: (context, snap) => Text(
                snap.data == null ? '' : 'Versão ${snap.data}',
                style: tema.bodySmall?.copyWith(color: cor.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: Spacing.sp24),
            Text('Fontes do texto', style: tema.headlineSmall),
            const SizedBox(height: Spacing.sp10),
            Text(
              'Este aplicativo utiliza uma tradução autoral e inédita da '
              'King James 1611, elaborada diretamente do texto '
              'inglês em domínio público. Também reúne traduções próprias '
              'dos devocionais clássicos de Charles H. Spurgeon, Morning '
              'and Evening e Faith\'s Checkbook. O texto busca conservar '
              'fidelidade teológica, reverência literária e rigor no respeito '
              'aos direitos autorais.',
              style: tema.bodyLarge?.copyWith(height: 1.7),
            ),
            const SizedBox(height: Spacing.sp32),
            Text('A voz de Spurgeon', style: tema.headlineSmall),
            const SizedBox(height: Spacing.sp10),
            Text(
              'O retrato de Spurgeon nas telas de leitura lê o texto em voz '
              'alta: um narrador masculino de barítono, sintetizado na nuvem '
              'do Google, lendo devagar e em tom grave. A leitura precisa da '
              'rede, e o limite gratuito de um milhão de caracteres por mês '
              'cobre o uso de sobra. A demonstração abaixo toca só os três '
              'primeiros versículos do Salmo 1.',
              style: tema.bodyLarge?.copyWith(height: 1.7),
            ),
            const SizedBox(height: Spacing.sp16),
            // A demonstração no próprio lugar da explicação: quem descobre a
            // voz aqui ouve na hora, sem caçar um capítulo para testar.
            Text(
              'Ouça um trecho:',
              style: tema.labelLarge?.copyWith(color: cor.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sp10),
            CarregaUmaVez<Capitulo>(
              chave: 'voz-demo-salmos-1-$_tentativasDaDemo',
              carregar: () =>
                  Conteudo.instancia.capitulo('salmos', 1),
              construir: (context, snap) {
                if (snap.hasError) {
                  // A demonstração não pode sumir em silêncio: quem a pediu
                  // precisa saber que o trecho não veio, e de um jeito de
                  // pedir de novo.
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar de novo'),
                      onPressed: () => setState(() => _tentativasDaDemo++),
                    ),
                  );
                }
                final capitulo = snap.data;
                if (capitulo == null ||
                    snap.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                // A demonstração toca só os três primeiros versículos, não o
                // capítulo inteiro: o que se promete aqui é um trecho, e a
                // pílula não deve gastar a quota de um Salmo 1 completo. A
                // chave própria ("trecho:...") também impede que o trecho
                // encurte o áudio do capítulo completo na cache da Bíblia.
                final trecho = [
                  capitulo.referencia,
                  for (final (numero, texto) in capitulo.versiculos.take(3))
                    '$numero. $texto',
                ].join(' ');
                return BotaoDeVoz(
                  chave: 'trecho:${capitulo.livro}.${capitulo.numero}',
                  texto: trecho,
                  tipo: TipoConteudoAudio.biblia,
                  // Sem referência: "Leitura concluída." basta — o que
                  // terminou foi o trecho, não o capítulo.
                );
              },
            ),
            const SizedBox(height: Spacing.sp32),
            Text('Onde me encontrar', style: tema.headlineSmall),
            const SizedBox(height: Spacing.sp10),
            _LinkDeCanal(
              asset: 'assets/images/youtube.webp',
              rotulo: 'YouTube',
              url: 'https://www.youtube.com/@felipe_ambrozini',
            ),
            _LinkDeCanal(
              asset: 'assets/images/instagram.webp',
              rotulo: 'Instagram',
              url: 'https://www.instagram.com/felipe_ambrozini/',
            ),
            const SizedBox(height: Spacing.sp32),
            Text('Ajuda', style: tema.headlineSmall),
            const SizedBox(height: Spacing.sp10),
            // A ajuda não pode morar só no primeiro dia: quem dispensou o
            // cartão da Hoje não tem como vê-lo de novo, e Sobre é onde se
            // procura por ajuda quando se procura.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.help_outline, color: cor.primary),
              title: const Text('Como usar'),
              subtitle: const Text('O cartão da primeira visita, de novo.'),
              onTap: () => _mostrarAjuda(context),
            ),
            // A conta na nuvem existe em todas as plataformas (ver
            // nuvem.dart); esta seção é a de privacidade e apagar dados.
            if (nuvemSuportada) ...[
              const SizedBox(height: Spacing.sp32),
              Text('Conta e privacidade', style: tema.headlineSmall),
              const SizedBox(height: Spacing.sp10),
              ListenableBuilder(
                listenable: Nuvem.instancia,
                // O histórico do chat só existe para quem tem acesso à
                // função (ver Recursos.conversas); citá-lo para quem não
                // pode usar o chat só confundiria.
                builder: (context, _) => Text(
                  Recursos.conversas
                      ? 'Quem entra com a conta Google salva favoritos, '
                            'anotações, dias de leitura marcados e o '
                            'histórico das conversas do chat numa conta na '
                            'nuvem, para não perdê-los se o navegador '
                            'limpar o armazenamento. Sobem só esses itens, '
                            'mais o e-mail e o identificador da conta, '
                            'nunca o texto da Bíblia ou do devocional que '
                            'você lê; o tamanho da letra e o tema continuam '
                            'só no aparelho. Quem não entra usa o app do '
                            'mesmo jeito de sempre, sem nada saindo daqui.'
                      : 'Quem entra com a conta Google salva favoritos, '
                            'anotações e dias de leitura marcados numa '
                            'conta na nuvem, para não perdê-los se o '
                            'navegador limpar o armazenamento. Sobem só '
                            'esses itens, mais o e-mail e o identificador '
                            'da conta, nunca o texto da Bíblia ou do '
                            'devocional que você lê; o tamanho da letra e o '
                            'tema continuam só no aparelho. Quem não entra '
                            'usa o app do mesmo jeito de sempre, sem nada '
                            'saindo daqui.',
                  style: tema.bodyLarge?.copyWith(height: 1.7),
                ),
              ),
              const SizedBox(height: Spacing.sp10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.privacy_tip_outlined, color: cor.primary),
                title: const Text('Política de privacidade completa'),
                onTap: () => GoRouter.of(context).push('/privacidade'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined, color: cor.primary),
                title: const Text('Termos de serviço'),
                onTap: () => GoRouter.of(context).push('/termos'),
              ),
              const SizedBox(height: Spacing.sp8),
              ListenableBuilder(
                listenable: Nuvem.instancia,
                builder: (context, _) => Nuvem.instancia.logado
                    ? ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline, color: cor.error),
                        title: const Text('Apagar meus dados da nuvem'),
                        subtitle: const Text(
                          'Remove a cópia salva na conta. O que está neste '
                          'navegador não é tocado.',
                        ),
                        onTap: () => _apagarDaNuvem(context),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// As mesmas linhas do cartão "Como usar" da Hoje, num diálogo: a ajuda
/// sobrevive ao "Entendi" da primeira visita.
Future<void> _mostrarAjuda(BuildContext context) {
  final tema = Theme.of(context).textTheme;
  return showDialog<void>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Como usar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final linha in linhasDeAjuda) ...[
              Text(linha, style: tema.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: Spacing.sp8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogo),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}

/// Confirma e apaga a cópia da conta. O "não pode ser desfeita" é literal:
/// `Nuvem.apagarDados` remove o documento no Firestore e a conta em si.
Future<void> _apagarDaNuvem(BuildContext context) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Apagar dados da nuvem?',
    conteudo:
        'Favoritos, anotações e progresso salvos na sua conta serão '
        'apagados. O que está neste navegador continua intacto. Essa ação '
        'não pode ser desfeita.',
    rotuloDaAcao: 'Apagar',
  );
  if (!confirmou || !context.mounted) return;

  final mensageiro = ScaffoldMessenger.of(context);
  try {
    await Nuvem.instancia.apagarDados();
    mostrarAvisoNo(mensageiro, 'Dados apagados da nuvem.');
  } catch (_) {
    mostrarErroNo(mensageiro, 'Não foi possível apagar agora. Tente de novo.');
  }
}

class _LinkDeCanal extends StatelessWidget {
  const _LinkDeCanal({
    required this.asset,
    required this.rotulo,
    required this.url,
  });

  final String asset;
  final String rotulo;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Image.asset(
        asset,
        // O logo oficial da marca, como o "G" do Google: não redesenhado.
        width: 26,
        height: 26,
      ),
      title: Text(rotulo),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}