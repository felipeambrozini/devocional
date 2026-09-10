import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controladores/sobre_controlador.dart';
import '../dados/coleta.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/nuvem.dart';
import '../dados/personas.dart';
import '../dados/recursos.dart';
import '../dados/voz.dart';
import '../estilo/spacing.dart';
import '../funcoes/aviso.dart';
import '../funcoes/linhas_de_ajuda.dart';
import '../widgets/widgets.dart';

/// E-mail que recebe "Relatar um problema" — mesmo padrão de
/// `--dart-define` das outras chaves, para não versionar um endereço
/// pessoal no repositório (ver o que já foi tirado de `Recursos`). Vazio
/// esconde o item: sem endereço configurado, um mailto: sem destino só
/// confundiria.
const _emailDeContato = String.fromEnvironment('EMAIL_DE_CONTATO');

/// Créditos das traduções, da fonte dos devocionais e o link dos canais.
class TelaSobre extends StatefulWidget {
  const TelaSobre({super.key});

  @override
  State<TelaSobre> createState() => _TelaSobreState();
}

class _TelaSobreState extends State<TelaSobre> {
  late final _controller = SobreControlador();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: DevocionalAppBar(
          title: const Text('Sobre'),
          actions: [
            DevocionalBotaoDeAjustes(estado: EscopoDoEstado.de(context)),
            // A demonstração vive num ListView: quem rola até a ajuda não vê
            // mais a pílula, e o trecho não pode tocar sem o botão de parar à
            // vista. O indicador também cobre o trecho pausado (chamada).
            const DevocionalIndicadorDeVozNaBarra(chave: 'trecho:salmos.1'),
          ],
        ),
        body: DevocionalLarguraDeLeitura(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DevocionalEspacamento.sp20,
              DevocionalEspacamento.sp16,
              DevocionalEspacamento.sp20,
              DevocionalEspacamento.sp40,
            ),
            children: [
              Text('Devocional', style: tema.displayMedium),
              const SizedBox(height: DevocionalEspacamento.sp8),
              const DevocionalFilete(largura: 64),
              const SizedBox(height: DevocionalEspacamento.sp12),
              // A versão pequena, sem alarde, é o que basta para quem quer
              // conferir se está na última compilação.
              DevocionalCarregaUmaVez<String>(
                chave: 'versao',
                carregar: () async =>
                    (await PackageInfo.fromPlatform()).version,
                construir: (context, snap) => Text(
                  snap.data == null ? '' : 'Versão ${snap.data}',
                  style: tema.bodySmall?.copyWith(color: cor.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: DevocionalEspacamento.sp24),
              Text('Fontes do texto', style: tema.headlineSmall),
              const SizedBox(height: DevocionalEspacamento.sp10),
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
              const SizedBox(height: DevocionalEspacamento.sp32),
              Text('A voz de Spurgeon', style: tema.headlineSmall),
              const SizedBox(height: DevocionalEspacamento.sp10),
              Text(
                'O retrato de Spurgeon nas telas de leitura lê o texto em voz '
                'alta: MP3 pré-gravados numa voz que remete ao tom de Charles '
                'Spurgeon, mais natural que uma síntese em tempo real. Fora '
                'da web dá para '
                'baixar por categoria e ouvir offline, nos Ajustes. A '
                'demonstração abaixo toca o Salmo 23.',
                style: tema.bodyLarge?.copyWith(height: 1.7),
              ),
              const SizedBox(height: DevocionalEspacamento.sp16),
              // A demonstração no próprio lugar da explicação: quem descobre a
              // voz aqui ouve na hora, sem caçar um capítulo para testar.
              Text(
                'Ouça uma amostra:',
                style: tema.labelLarge?.copyWith(color: cor.onSurfaceVariant),
              ),
              const SizedBox(height: DevocionalEspacamento.sp10),
              DevocionalCarregaUmaVez<Capitulo>(
                chave: 'voz-demo-salmos-23-${_controller.tentativasDaDemo}',
                carregar: () => Conteudo.instancia.capitulo('salmos', 23),
                construir: (context, snap) {
                  if (snap.hasError) {
                    // A demonstração não pode sumir em silêncio: quem a pediu
                    // precisa saber que ela não veio, e de um jeito de pedir de
                    // novo.
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const FaIcon(FontAwesomeIcons.arrowsRotate),
                        label: const Text('Tentar de novo'),
                        onPressed: _controller.tentarDeNovo,
                      ),
                    );
                  }
                  final capitulo = snap.data;
                  if (capitulo == null ||
                      snap.connectionState != ConnectionState.done) {
                    return const SizedBox.shrink();
                  }
                  // O Salmo 23 tem só seis versículos: curto o bastante para
                  // servir de amostra tocando o capítulo inteiro, com a mesma
                  // chave (e o mesmo arquivo) que o leitor usa.
                  return DevocionalBotaoDeVoz(
                    chave: chaveDeCapitulo(capitulo.livro, capitulo.numero),
                    referencia: capitulo.referencia,
                  );
                },
              ),
              const SizedBox(height: DevocionalEspacamento.sp32),
              Text('Sobre mim', style: tema.headlineSmall),
              const SizedBox(height: DevocionalEspacamento.sp12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const DevocionalRetratoDePersona(
                    persona: personaFelipe,
                    tamanho: 72,
                    folga: DevocionalEspacamento.sp3,
                  ),
                  const SizedBox(width: DevocionalEspacamento.sp14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Felipe Ambrozini', style: tema.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Criador do app',
                          style: tema.labelMedium?.copyWith(
                            color: cor.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DevocionalEspacamento.sp12),
              Text(
                'Sou cristão, criador de conteúdo e desenvolvedor. Criei este '
                'app para meu uso diário de leitura bíblica e dos devocionais '
                'de Spurgeon e o abri para quem quiser usar também. Aqui reúno '
                'ensino bíblico, devocionais e ferramentas simples de leitura, '
                'sempre apontando para Cristo.',
                style: tema.bodyLarge?.copyWith(height: 1.7),
              ),
              const SizedBox(height: DevocionalEspacamento.sp32),
              Text('Onde me encontrar', style: tema.headlineSmall),
              const SizedBox(height: DevocionalEspacamento.sp10),
              DevocionalLinkDeCanal(
                asset: 'assets/images/youtube.webp',
                rotulo: 'YouTube',
                url: 'https://www.youtube.com/@felipe_ambrozini',
              ),
              DevocionalLinkDeCanal(
                asset: 'assets/images/instagram.webp',
                rotulo: 'Instagram',
                url: 'https://www.instagram.com/felipe_ambrozini/',
              ),
              const SizedBox(height: DevocionalEspacamento.sp32),
              Text('Ajuda', style: tema.headlineSmall),
              const SizedBox(height: DevocionalEspacamento.sp10),
              // A ajuda não pode morar só no primeiro dia: quem dispensou o
              // cartão da Hoje não tem como vê-lo de novo, e Sobre é onde se
              // procura por ajuda quando se procura.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: FaIcon(
                  FontAwesomeIcons.circleQuestion,
                  color: cor.primary,
                ),
                title: const Text('Como usar'),
                subtitle: const Text('O cartão da primeira visita, de novo.'),
                onTap: () => _mostrarAjuda(context),
              ),
              if (_emailDeContato.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: FaIcon(
                    FontAwesomeIcons.envelope,
                    color: cor.primary,
                  ),
                  title: const Text('Relatar um problema'),
                  subtitle: const Text(
                    'Abre um e-mail com a versão do app já preenchida.',
                  ),
                  onTap: _relatarProblema,
                ),
              // O aceite (ver TelaDeAceiteDeColeta) só pergunta uma vez; este
              // switch é como a política de privacidade promete "mudar de
              // ideia depois" sem exigir apagar dados do app inteiro.
              ListenableBuilder(
                listenable: EscopoDoEstado.de(context),
                builder: (context, _) {
                  final estado = EscopoDoEstado.de(context);
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: FaIcon(
                      FontAwesomeIcons.chartLine,
                      color: cor.primary,
                    ),
                    title: const Text('Erro técnico e uso anônimo'),
                    subtitle: const Text(
                      'Sentry (erro) e Analytics (uso por tela), sem '
                      'identificar você — ver Política de privacidade.',
                    ),
                    value: estado.aceiteDeColeta ?? false,
                    onChanged: (permitido) async {
                      await estado.definirAceiteDeColeta(permitido);
                      await aplicarAceiteDeColeta(permitido);
                    },
                  );
                },
              ),
              // A conta na nuvem existe em todas as plataformas (ver
              // nuvem.dart); esta seção é a de privacidade e apagar dados.
              if (nuvemSuportada) ...[
                const SizedBox(height: DevocionalEspacamento.sp32),
                Text('Conta e privacidade', style: tema.headlineSmall),
                const SizedBox(height: DevocionalEspacamento.sp10),
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
                const SizedBox(height: DevocionalEspacamento.sp10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: FaIcon(
                    FontAwesomeIcons.shieldHalved,
                    color: cor.primary,
                  ),
                  title: const Text('Política de privacidade completa'),
                  onTap: () => GoRouter.of(context).push('/privacidade'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: FaIcon(
                    FontAwesomeIcons.fileLines,
                    color: cor.primary,
                  ),
                  title: const Text('Termos de serviço'),
                  onTap: () => GoRouter.of(context).push('/termos'),
                ),
                const SizedBox(height: DevocionalEspacamento.sp8),
                ListenableBuilder(
                  listenable: Nuvem.instancia,
                  builder: (context, _) => Nuvem.instancia.logado
                      ? ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: FaIcon(
                            FontAwesomeIcons.trash,
                            color: cor.error,
                          ),
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
              const SizedBox(height: DevocionalEspacamento.sp8),
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

/// Abre o cliente de e-mail com assunto e corpo já preenchidos — versão e
/// plataforma, para o testador não precisar descobrir e digitar isso
/// sozinho. Só é chamado quando [_emailDeContato] não está vazio (ver o
/// `if` no `ListTile`).
Future<void> _relatarProblema() async {
  final info = await PackageInfo.fromPlatform();
  final plataforma = kIsWeb
      ? 'Web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'Android',
          TargetPlatform.iOS => 'iOS',
          final outra => outra.name,
        };
  final uri = Uri(
    scheme: 'mailto',
    path: _emailDeContato,
    queryParameters: {
      'subject': 'Devocional: relatar um problema',
      'body':
          'Versão ${info.version}+${info.buildNumber} — $plataforma\n\n'
          'Descreva o que aconteceu:\n',
    },
  );
  await launchUrl(uri);
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
