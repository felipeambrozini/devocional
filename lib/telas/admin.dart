import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/config_admin.dart';
import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../dados/registro.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../widgets/widgets.dart';

/// Painel admin: interruptores de cada recurso e as allowlists do chat e dos
/// planos.
///
/// Só web e só a conta do dono (ver `Recursos.adminNaWeb`): fora da web ou
/// sem esse login, a rota `/admin` redireciona para `/hoje` (ver `main.dart`)
/// e esta tela mostra o motivo em vez do conteúdo — defesa em profundidade,
/// para um link direto nunca vazar o painel.
///
/// Tudo grava no Firestore (`config/recursos`) e vale na hora, sem
/// reimplantar: o app inteiro ouve o documento (ver `ConfigAdmin.iniciar`).
class TelaAdmin extends StatefulWidget {
  const TelaAdmin({super.key});

  @override
  State<TelaAdmin> createState() => _TelaAdminState();
}

class _TelaAdminState extends State<TelaAdmin> {
  /// Campos com escrita no voo. Um por linha: o switch desabilita e mostra o
  /// giro até o Firestore responder, para o toque não parecer morto nem
  /// duplicar a escrita.
  final _salvando = <String>{};

  Future<void> _alternar(String campo, String rotulo, bool valor) async {
    if (_salvando.contains(campo)) return;
    // Desligar o chat corta todas as contas na hora: o único gesto da tela
    // que pede confirmação antes, proporcional ao estrago de um toque errado.
    if (campo == 'conversasAtivas' && !valor) {
      final pode = await confirmar(
        context,
        titulo: 'Desligar conversas?',
        conteudo:
            'O chat com Spurgeon e com Felipe para em todas as contas na hora.',
        rotuloDaAcao: 'Desligar',
      );
      if (!pode || !mounted) return;
    }
    setState(() => _salvando.add(campo));
    try {
      await ConfigAdmin.instancia.definir(campo, valor);
    } catch (erro, pilha) {
      Registro.erro('Admin.alternar:$campo', erro, pilha);
      if (mounted) {
        mostrarErro(
          context,
          '$rotulo: não foi possível salvar.',
          rotuloDeAcao: 'Tentar de novo',
          aoAgir: () => _alternar(campo, rotulo, valor),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando.remove(campo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DevocionalAppBar(title: Text('Administração')),
      body: DevocionalLarguraDeLeitura(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            ConfigAdmin.instancia,
            Nuvem.instancia,
          ]),
          builder: (context, _) {
            if (!kIsWeb) {
              return const DevocionalAvisoVazio(
                icone: FontAwesomeIcons.globe,
                titulo: 'Só na web',
                detalhe:
                    'O painel admin é ferramenta de escritório: abra no navegador.',
              );
            }
            if (!Nuvem.instancia.logado) {
              return const DevocionalAvisoVazio(
                icone: FontAwesomeIcons.lock,
                titulo: 'Entre para continuar',
                detalhe: 'O painel admin exige a conta do dono logada.',
              );
            }
            if (!Recursos.ehAdmin) {
              return const DevocionalAvisoVazio(
                icone: FontAwesomeIcons.lock,
                titulo: 'Acesso restrito',
                detalhe: 'Esta conta não tem acesso ao painel admin.',
              );
            }
            return _conteudo(context);
          },
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final config = ConfigAdmin.instancia;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DevocionalEspacamento.sp20,
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp20,
        DevocionalEspacamento.sp40,
      ),
      children: [
        Text('Administração', style: tema.displayMedium),
        const SizedBox(height: DevocionalEspacamento.sp8),
        const DevocionalFilete(largura: 64),
        const SizedBox(height: DevocionalEspacamento.sp8),
        Text(
          config.carregado
              ? 'Sincronizado com a nuvem. Mudar aqui vale na hora, sem reimplantar.'
              : 'Carregando a configuração...',
          style: tema.bodySmall,
        ),
        const SizedBox(height: DevocionalEspacamento.sp16),
        Text('Recursos', style: tema.headlineSmall),
        // Sem a configuração, os switches mostravam o padrão ligado como se
        // fosse o estado real — e um toque ali sobrescrevia o servidor. Sem
        // ela, só o giro: nada se liga nem desliga antes de saber a verdade.
        if (!config.carregado)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: DevocionalEspacamento.sp24,
            ),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (config.carregado)
          _Interruptor(
            titulo: 'Conversas (chat)',
            subtitulo: 'Interruptor geral: desligado, ninguém conversa.',
            valor: config.conversasAtivas,
            salvando: _salvando.contains('conversasAtivas'),
            aoMudar: (novo) => _alternar('conversasAtivas', 'Conversas', novo),
          ),
        if (config.carregado)
          _Interruptor(
            titulo: 'Planos personalizados',
            subtitulo: 'A aba Meus planos e a criação de planos próprios.',
            valor: config.planoPersonalizadoAtivo,
            salvando: _salvando.contains('planoPersonalizadoAtivo'),
            aoMudar: (novo) => _alternar(
              'planoPersonalizadoAtivo',
              'Planos personalizados',
              novo,
            ),
          ),
        if (config.carregado)
          _Interruptor(
            titulo: 'Cronograma anual',
            subtitulo: 'A aba Cronograma dentro do Plano.',
            valor: config.cronogramaAtivo,
            salvando: _salvando.contains('cronogramaAtivo'),
            aoMudar: (novo) => _alternar('cronogramaAtivo', 'Cronograma', novo),
          ),
        if (config.carregado)
          _Interruptor(
            titulo: 'Devocional da manhã',
            subtitulo: 'A leitura Manhã no Devocional e na Hoje.',
            valor: config.manhaAtivo,
            salvando: _salvando.contains('manhaAtivo'),
            aoMudar: (novo) => _alternar('manhaAtivo', 'Manhã', novo),
          ),
        if (config.carregado)
          _Interruptor(
            titulo: 'Devocional da noite',
            subtitulo: 'A leitura Noite no Devocional e na Hoje.',
            valor: config.noiteAtivo,
            salvando: _salvando.contains('noiteAtivo'),
            aoMudar: (novo) => _alternar('noiteAtivo', 'Noite', novo),
          ),
        if (config.carregado)
          _Interruptor(
            titulo: 'Promessas de Deus',
            subtitulo: 'A leitura Promessas no Devocional e na Hoje.',
            valor: config.promessasAtivo,
            salvando: _salvando.contains('promessasAtivo'),
            aoMudar: (novo) => _alternar('promessasAtivo', 'Promessas', novo),
          ),
        if (config.carregado)
          _Interruptor(
            titulo: 'Ouvir textos',
            subtitulo:
                'O botão Ouvir na Bíblia, no devocional e nas introduções.',
            valor: config.ouvirTextosAtivo,
            salvando: _salvando.contains('ouvirTextosAtivo'),
            aoMudar: (novo) =>
                _alternar('ouvirTextosAtivo', 'Ouvir textos', novo),
          ),
        const SizedBox(height: DevocionalEspacamento.sp24),
        const DevocionalFilete(largura: 64),
        const SizedBox(height: DevocionalEspacamento.sp16),
        _SecaoDeEmails(
          titulo: 'E-mails com conversas',
          legendaVazia: 'Ninguém liberado ainda.',
          legendaCheia: (n) =>
              '$n ${n == 1 ? 'conta liberada' : 'contas liberadas'}.',
          emails: config.emailsComConversas,
          textoDeRemocao: (email) => '$email perde o chat na hora.',
          aoAdicionar: ConfigAdmin.instancia.adicionarEmail,
          aoRemover: ConfigAdmin.instancia.removerEmail,
          contextoDeErro: 'Admin.emailsComConversas',
          autofocus: true,
        ),
        const SizedBox(height: DevocionalEspacamento.sp24),
        const DevocionalFilete(largura: 64),
        const SizedBox(height: DevocionalEspacamento.sp16),
        _SecaoDeEmails(
          titulo: 'E-mails com planos',
          legendaVazia:
              'Lista vazia: vale só o interruptor de planos acima. Com o '
              'primeiro e-mail, só quem está aqui cria planos.',
          legendaCheia: (n) =>
              '$n ${n == 1 ? 'conta liberada' : 'contas liberadas'}.',
          emails: config.emailsComPlanos,
          textoDeRemocao: (email) => '$email perde os planos na hora.',
          aoAdicionar: ConfigAdmin.instancia.adicionarEmailAosPlanos,
          aoRemover: ConfigAdmin.instancia.removerEmailDosPlanos,
          contextoDeErro: 'Admin.emailsComPlanos',
        ),
      ],
    );
  }
}

/// Uma allowlist do painel: título, contagem, campo de adicionar e a lista
/// com remover. Estado próprio (campo, giro, erro) por seção: as duas seções
/// da tela não dividem controlador, senão digitar numa espelhava na outra.
/// Extraída da seção de conversas quando os planos ganharam a sua.
class _SecaoDeEmails extends StatefulWidget {
  const _SecaoDeEmails({
    required this.titulo,
    required this.legendaVazia,
    required this.legendaCheia,
    required this.emails,
    required this.textoDeRemocao,
    required this.aoAdicionar,
    required this.aoRemover,
    required this.contextoDeErro,
    this.autofocus = false,
  });

  final String titulo;
  final String legendaVazia;
  final String Function(int total) legendaCheia;
  final List<String> emails;
  final String Function(String email) textoDeRemocao;
  final Future<void> Function(String email) aoAdicionar;
  final Future<void> Function(String email) aoRemover;
  final String contextoDeErro;

  /// Só a primeira seção pede foco ao abrir: dois campos com autofocus
  /// brigariam pelo teclado.
  final bool autofocus;

  @override
  State<_SecaoDeEmails> createState() => _SecaoDeEmailsState();
}

class _SecaoDeEmailsState extends State<_SecaoDeEmails> {
  final _email = TextEditingController();
  bool _adicionando = false;
  String? _erroDoEmail;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    if (_adicionando) return;
    setState(() {
      _adicionando = true;
      _erroDoEmail = null;
    });
    try {
      await widget.aoAdicionar(_email.text);
      _email.clear();
      if (mounted) mostrarAviso(context, 'E-mail liberado.');
    } on FormatException catch (erro) {
      // Erro de digitação volta para o campo, não só para o aviso: o foco
      // fica onde se corrige.
      if (mounted) setState(() => _erroDoEmail = erro.message);
    } catch (erro, pilha) {
      Registro.erro(widget.contextoDeErro, erro, pilha);
      if (mounted) {
        mostrarErro(context, 'Não foi possível adicionar. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _adicionando = false);
    }
  }

  Future<void> _remover(String email) async {
    final pode = await confirmar(
      context,
      titulo: 'Remover acesso?',
      conteudo: widget.textoDeRemocao(email),
      rotuloDaAcao: 'Remover',
    );
    if (!pode || !mounted) return;
    try {
      await widget.aoRemover(email);
      if (mounted) mostrarAviso(context, 'Acesso removido.');
    } catch (erro, pilha) {
      Registro.erro(widget.contextoDeErro, erro, pilha);
      if (mounted) {
        mostrarErro(context, 'Não foi possível remover. Tente de novo.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.titulo, style: tema.headlineSmall),
        const SizedBox(height: DevocionalEspacamento.sp4),
        Text(
          widget.emails.isEmpty
              ? widget.legendaVazia
              : widget.legendaCheia(widget.emails.length),
          style: tema.bodySmall,
        ),
        const SizedBox(height: DevocionalEspacamento.sp8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              // Sem `border:` no InputDecoration de propósito: o
              // inputDecorationTheme (ver tema.dart) já dá fill, 12px e o fio
              // do metal com foco primário — o override com OutlineInputBorder
              // cru apagava tudo isso.
              child: TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                enableSuggestions: false,
                autofocus: widget.autofocus,
                enabled: !_adicionando,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'E-mail para liberar',
                  hintText: 'alguem@exemplo.com',
                  errorText: _erroDoEmail,
                ),
                onSubmitted: (_) => _adicionar(),
              ),
            ),
            const SizedBox(width: DevocionalEspacamento.sp8),
            DevocionalBotaoPrimario(
              onPressed: _adicionando ? null : _adicionar,
              child: _adicionando
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: DevocionalEspacamento.sp8),
        for (final email in widget.emails)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FaIcon(
              FontAwesomeIcons.circleUser,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(email, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Remover acesso de $email',
              icon: const FaIcon(FontAwesomeIcons.trash),
              onPressed: () => _remover(email),
            ),
          ),
      ],
    );
  }
}

/// Uma linha do painel: título, explicação e o interruptor. Com escrita no
/// voo ([salvando]), o switch desabilita e o giro ocupa o lugar do ícone à
/// esquerda — o toque tem resposta na hora, sem parecer morto.
class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.aoMudar,
    this.salvando = false,
  });

  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> aoMudar;
  final bool salvando;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(titulo),
      subtitle: Text(subtitulo),
      value: valor,
      onChanged: salvando ? null : aoMudar,
      secondary: salvando
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}
