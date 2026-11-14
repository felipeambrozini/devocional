import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controladores/sobre_controlador.dart';
import '../dados/contato.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/nuvem.dart';
import '../dados/personas.dart';
import '../dados/recursos.dart';
import '../dados/registro.dart';
import '../dados/voz.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/linhas_de_ajuda.dart';
import '../widgets/widgets.dart';

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
            // A demonstração vive dentro de "A voz de Spurgeon", uma seção
            // expansível aberta por padrão (ver DevocionalSecaoExpansivel): quem rola
            // para longe dela, ou a fecha, não vê mais a pílula, e o trecho
            // não pode tocar sem o botão de parar à vista. O indicador também
            // cobre o trecho pausado (chamada).
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
              Semantics(
                header: true,
                child: Text('Devocional', style: tema.displayMedium),
              ),
              const SizedBox(height: DevocionalEspacamento.sp8),
              const DevocionalFilete(largura: 64),
              const SizedBox(height: DevocionalEspacamento.sp12),
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
              // Ajuda e Conta e privacidade vêm primeiro: são a razão mais
              // comum de abrir Sobre (ajuda, apagar dados). O que é crédito/leitura de referência (fontes,
              // voz, biografia, canais) vem depois, colapsado.
              Semantics(
                header: true,
                child: Text('Ajuda', style: tema.headlineSmall),
              ),
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
              if (emailDeContato.isNotEmpty)
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
              // Sem coleta remota neste app (sem Sentry, sem Analytics):
              // erro fica no console e em arquivo local. "Relatar um
              // problema" abaixo abre e-mail com a versão já preenchida.
              const SizedBox(height: DevocionalEspacamento.sp32),
              Semantics(
                header: true,
                child: Text('Conta e privacidade', style: tema.headlineSmall),
              ),
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
                leading: FaIcon(FontAwesomeIcons.fileLines, color: cor.primary),
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
              const SizedBox(height: DevocionalEspacamento.sp32),
              // As quatro seções abaixo são conteúdo de referência, lido uma
              // vez e raramente revisitado — colapsadas por padrão e depois
              // de Ajuda/Conta e privacidade, que são a razão mais comum de
              // abrir esta tela.
              DevocionalSecaoExpansivel(
                icone: FontAwesomeIcons.bookBible,
                titulo: 'Fontes do texto',
                children: [
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
                  const SizedBox(height: DevocionalEspacamento.sp16),
                  Text(
                    avisoDaBibliaDeEstudo,
                    style: tema.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp16),
                  // Atribuição exigida pela licença CC BY 4.0 dos dados.
                  Text(
                    'As palavras de Deus em vermelho seguem os dados de falas '
                    'e falantes do MACULA Quotation and Speaker Data, © 2023 '
                    'Clear Bible, Inc. (CC BY 4.0), com dados da SIL e da '
                    'Faith Comes By Hearing, adaptados ao texto em português.',
                    style: tema.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp16),
                ],
              ),
              DevocionalSecaoExpansivel(
                icone: FontAwesomeIcons.volumeHigh,
                titulo: 'A voz de Spurgeon',
                abertaPorPadrao: true,
                children: [
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
                    style: tema.labelLarge?.copyWith(
                      color: cor.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp10),
                  DevocionalCarregaUmaVez<Capitulo>(
                    chave: 'voz-demo-salmos-23-${_controller.tentativasDaDemo}',
                    carregar: () => Conteudo.instancia.capitulo('salmos', 23),
                    construir: (context, snap) {
                      if (snap.hasError) {
                        // A demonstração não pode sumir em silêncio: quem a
                        // pediu precisa saber que ela não veio, e de um jeito
                        // de pedir de novo.
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: DevocionalBotaoTerciario.icon(
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
                      // O Salmo 23 tem só seis versículos: curto o bastante
                      // para servir de amostra tocando o capítulo inteiro, com
                      // a mesma chave (e o mesmo arquivo) que o leitor usa.
                      return DevocionalBotaoDeVoz(
                        chave: chaveDeCapitulo(capitulo.livro, capitulo.numero),
                        referencia: capitulo.referencia,
                      );
                    },
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp16),
                ],
              ),
              DevocionalSecaoExpansivel(
                icone: FontAwesomeIcons.user,
                titulo: 'Sobre mim',
                children: [
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
                  const SizedBox(height: DevocionalEspacamento.sp16),
                ],
              ),
              DevocionalSecaoExpansivel(
                icone: FontAwesomeIcons.shareNodes,
                titulo: 'Onde me encontrar',
                children: [
                  DevocionalLinkDeCanal(
                    asset: 'assets/imagens/youtube.webp',
                    rotulo: 'YouTube',
                    url: 'https://www.youtube.com/@felipe_ambrozini',
                  ),
                  DevocionalLinkDeCanal(
                    asset: 'assets/imagens/instagram.webp',
                    rotulo: 'Instagram',
                    url: 'https://www.instagram.com/felipe_ambrozini/',
                  ),
                ],
              ),
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
      title: Text('Como usar', style: tema.headlineSmall),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DevocionalFilete(largura: 64),
            const SizedBox(height: DevocionalEspacamento.sp12),
            for (final linha in linhasDeAjuda) ...[
              Text(linha, style: tema.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: DevocionalEspacamento.sp8),
            ],
          ],
        ),
      ),
      actions: [
        DevocionalBotaoTerciario(
          onPressed: () => Navigator.pop(dialogo),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}

/// Abre o cliente de e-mail com assunto e corpo já preenchidos — versão e
/// plataforma, para o testador não precisar descobrir e digitar isso
/// sozinho. Só é chamado quando [emailDeContato] não está vazio (ver o
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
  final uri = mailtoPara(
    emailDeContato,
    assunto: 'Devocional: relatar um problema',
    corpo:
        'Versão ${info.version}+${info.buildNumber}, $plataforma\n\n'
        'Descreva o que aconteceu:\n',
  );
  // Na web, na mesma aba: o padrão abre uma aba nova, que fica em branco
  // mostrando o próprio mailto: em vez de só chamar o programa de e-mail.
  await launchUrl(uri, webOnlyWindowName: '_self');
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
  } catch (erro, pilha) {
    Registro.erro('Sobre.apagarDaNuvem', erro, pilha);
    mostrarErroNo(mensageiro, 'Não foi possível apagar agora. Tente de novo.');
  }
}
