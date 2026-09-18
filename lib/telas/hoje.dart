import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../dados/estado.dart';
import '../dados/config_admin.dart';
import '../dados/modelos.dart';
import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../dados/registro.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/conta_acoes.dart';
import '../funcoes/datas.dart';
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

    return Scaffold(
      body: SafeArea(
        child: DevocionalLarguraDeLeitura(
          child: ListenableBuilder(
            listenable: ConfigAdmin.instancia,
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
                  _Cabecalho(data: agora),
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Bom dia, boa tarde ou boa noite, só para a saudação — separado de
/// [Periodo], que decide qual devocional (Manhã ou Noite) aparece na
/// prévia. O conteúdo é binário porque Spurgeon só escreveu duas partes por
/// dia; a saudação não precisa seguir a mesma régua.
String _saudacaoPelaHora(int hora) {
  if (hora < 6) return 'Boa noite';
  if (hora < 12) return 'Bom dia';
  if (hora < 18) return 'Boa tarde';
  return 'Boa noite';
}

/// As opções da folha de `_escolherFoto`: as duas fontes do `ImagePicker`
/// mais "remover", que só faz sentido quando já existe uma foto.
enum _AcaoDeFoto { camera, galeria, remover }

/// Deixa escolher entre câmera, galeria ou remover a foto atual — tudo num
/// toque no avatar de `_Cabecalho`.
Future<void> _escolherFoto(BuildContext context) async {
  final temFoto = Nuvem.instancia.fotoUrl != null;
  final acao = await showModalBottomSheet<_AcaoDeFoto>(
    context: context,
    builder: (folha) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DevocionalEspacamento.sp20,
              DevocionalEspacamento.sp20,
              DevocionalEspacamento.sp20,
              DevocionalEspacamento.sp8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto de perfil',
                  style: Theme.of(folha).textTheme.headlineSmall,
                ),
                const SizedBox(height: DevocionalEspacamento.sp8),
                const DevocionalFilete(largura: 64),
              ],
            ),
          ),
          ListTile(
            leading: FaIcon(
              FontAwesomeIcons.camera,
              color: Theme.of(folha).colorScheme.primary,
            ),
            title: const Text('Câmera'),
            onTap: () => Navigator.pop(folha, _AcaoDeFoto.camera),
          ),
          ListTile(
            leading: FaIcon(
              FontAwesomeIcons.images,
              color: Theme.of(folha).colorScheme.primary,
            ),
            title: const Text('Galeria'),
            onTap: () => Navigator.pop(folha, _AcaoDeFoto.galeria),
          ),
          if (temFoto)
            ListTile(
              leading: FaIcon(
                FontAwesomeIcons.trash,
                color: Theme.of(folha).colorScheme.primary,
              ),
              title: const Text('Remover foto'),
              onTap: () => Navigator.pop(folha, _AcaoDeFoto.remover),
            ),
        ],
      ),
    ),
  );
  if (acao == null || !context.mounted) return;

  final mensageiro = ScaffoldMessenger.of(context);
  if (acao == _AcaoDeFoto.remover) {
    try {
      await Nuvem.instancia.removerFoto();
    } catch (erro, pilha) {
      Registro.erro('_escolherFoto', erro, pilha);
      mostrarErroNo(mensageiro, 'Não foi possível remover a foto.');
    }
    return;
  }

  final arquivo = await ImagePicker().pickImage(
    source: acao == _AcaoDeFoto.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    // Foto de perfil não precisa da resolução da câmera; menor já poupa
    // banda no upload e no carregamento do avatar depois.
    maxWidth: 512,
    imageQuality: 85,
  );
  if (arquivo == null || !context.mounted) return;

  try {
    await Nuvem.instancia.atualizarFoto(await arquivo.readAsBytes());
  } catch (erro, pilha) {
    Registro.erro('_escolherFoto', erro, pilha);
    mostrarErroNo(mensageiro, 'Não foi possível atualizar a foto.');
  }
}

/// Confirma e executa o logout. Um toque no "Sair" não pode deslogar sem
/// pergunta: na web, o espelho na nuvem é a proteção contra o navegador
/// limpar o armazenamento local, e derrubar a sessão desarma essa proteção.
Future<void> _sairDaConta(BuildContext context) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Sair da conta?',
    conteudo:
        'Favoritos, notas e progresso ficam neste aparelho, mas a cópia na '
        'nuvem para de se atualizar. Na web, é ela que devolve os dados se o '
        'navegador limpar o armazenamento.',
    rotuloDaAcao: 'Sair',
  );
  if (!confirmou || !context.mounted) return;
  final mensageiro = ScaffoldMessenger.of(context);
  try {
    await Nuvem.instancia.sair();
    mostrarAvisoNo(mensageiro, 'Você saiu da conta.');
  } catch (erro, pilha) {
    Registro.erro('_sairDaConta', erro, pilha);
    mostrarErroNo(mensageiro, 'Não foi possível sair agora. Tente de novo.');
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.data});

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
              // Sem rótulo, "trocar foto" só se descobria tocando: o papel de
              // botão e o nome vão na semântica, e a dica no toque longo.
              Semantics(
                button: true,
                label: 'Trocar foto de perfil',
                child: GestureDetector(
                  onTap: () => _escolherFoto(context),
                  child: Tooltip(
                    message: 'Trocar foto de perfil',
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
              const SizedBox(width: DevocionalEspacamento.sp14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome != null ? '$saudacao, $nome' : saudacao,
                    style: tema.headlineMedium,
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp4),
                  Text(dataLonga(data), style: tema.bodySmall),
                ],
              ),
            ),
            // Entrar ou sair da conta, no fim do cabeçalho: o convite para
            // entrar mora aqui (e não mais na folha de ajustes), porque o
            // estado da conta muda a saudação ao lado.
            _BotaoDeConta(),
            // Hoje não tem AppBar onde pendurar a ação, e sem isto os ajustes
            // só seriam alcançáveis de duas das seis abas.
            DevocionalBotaoDeAjustes(estado: EscopoDoEstado.de(context)),
          ],
        );
      },
    );
  }
}

/// Entrar ou sair da conta, no fim do cabeçalho da Hoje. Uma linha só para
/// os dois estados, nunca os dois ao mesmo tempo: convite para entrar, ou o
/// botão "Sair" de quem já entrou (o e-mail fica no Sobre, em "Conta e
/// privacidade").
class _BotaoDeConta extends StatelessWidget {
  const _BotaoDeConta();

  @override
  Widget build(BuildContext context) {
    final nuvem = Nuvem.instancia;
    return ListenableBuilder(
      listenable: nuvem,
      builder: (context, _) => nuvem.logado
          ? DevocionalBotaoTerciario.icon(
              onPressed: () => _sairDaConta(context),
              icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 18),
              label: const Text('Sair'),
            )
          : DevocionalBotaoSecundario.icon(
              onPressed: nuvem.entrando
                  ? null
                  : () => entrarNaConta(context, nuvem),
              icon: nuvem.entrando
                  ? const SizedBox(
                      width: DevocionalEspacamento.sp18,
                      height: DevocionalEspacamento.sp18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const FaIcon(FontAwesomeIcons.google, size: 16),
              label: const Text('Entrar'),
            ),
    );
  }
}
