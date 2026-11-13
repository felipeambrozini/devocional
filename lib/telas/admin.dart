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

/// Painel admin: interruptores de cada recurso e a allowlist do chat.
///
/// Só web e só a conta do dono (ver `Recursos.adminNaWeb`): fora da web ou
/// sem esse login, a rota `/admin` redireciona para `/hoje` (ver `main.dart`)
/// e esta tela mostra o motivo em vez do conteúdo — defesa em profundidade,
/// para um link direto nunca vazar o painel.
///
/// Tudo grava no Firestore (`config/recursos` e `convidados/{email}`) e vale
/// na hora, sem reimplantar: o app inteiro ouve os dois (ver `ConfigAdmin`).
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

  /// Criado no primeiro uso, que só acontece com o painel aberto para o
  /// dono: nenhuma outra conta consegue listar os convidados.
  late final Stream<List<String>> _convidados = ConfigAdmin.instancia
      .ouvirConvidados();

  bool _migrando = false;

  Future<void> _migrarConvidados() async {
    setState(() => _migrando = true);
    try {
      await ConfigAdmin.instancia.migrarConvidados();
      if (mounted) mostrarAviso(context, 'Convidados migrados.');
    } catch (erro, pilha) {
      Registro.erro('Admin.migrarConvidados', erro, pilha);
      if (mounted) {
        mostrarErro(context, 'Não foi possível migrar. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _migrando = false);
    }
  }

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
            padding: EdgeInsets.symmetric(vertical: DevocionalEspacamento.sp24),
            child: Center(
              child: CircularProgressIndicator(semanticsLabel: 'Carregando'),
            ),
          ),
        if (config.carregado)
          DevocionalInterruptor(
            titulo: 'Conversas (chat)',
            subtitulo: 'Interruptor geral: desligado, ninguém conversa.',
            valor: config.conversasAtivas,
            salvando: _salvando.contains('conversasAtivas'),
            aoMudar: (novo) => _alternar('conversasAtivas', 'Conversas', novo),
          ),
        if (config.carregado)
          DevocionalInterruptor(
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
          DevocionalInterruptor(
            titulo: 'Cronograma anual',
            subtitulo: 'A aba Cronograma dentro do Plano.',
            valor: config.cronogramaAtivo,
            salvando: _salvando.contains('cronogramaAtivo'),
            aoMudar: (novo) => _alternar('cronogramaAtivo', 'Cronograma', novo),
          ),
        if (config.carregado)
          DevocionalInterruptor(
            titulo: 'Devocional da manhã',
            subtitulo: 'A leitura Manhã no Devocional e na Hoje.',
            valor: config.manhaAtivo,
            salvando: _salvando.contains('manhaAtivo'),
            aoMudar: (novo) => _alternar('manhaAtivo', 'Manhã', novo),
          ),
        if (config.carregado)
          DevocionalInterruptor(
            titulo: 'Devocional da noite',
            subtitulo: 'A leitura Noite no Devocional e na Hoje.',
            valor: config.noiteAtivo,
            salvando: _salvando.contains('noiteAtivo'),
            aoMudar: (novo) => _alternar('noiteAtivo', 'Noite', novo),
          ),
        if (config.carregado)
          DevocionalInterruptor(
            titulo: 'Promessas de Deus',
            subtitulo: 'A leitura Promessas no Devocional e na Hoje.',
            valor: config.promessasAtivo,
            salvando: _salvando.contains('promessasAtivo'),
            aoMudar: (novo) => _alternar('promessasAtivo', 'Promessas', novo),
          ),
        if (config.carregado)
          DevocionalInterruptor(
            titulo: 'Ouvir textos',
            subtitulo:
                'O botão Ouvir na Bíblia, no devocional e nas introduções.',
            valor: config.ouvirTextosAtivo,
            salvando: _salvando.contains('ouvirTextosAtivo'),
            aoMudar: (novo) =>
                _alternar('ouvirTextosAtivo', 'Ouvir textos', novo),
          ),
        if (config.carregado)
          DevocionalInterruptor(
            titulo: 'Biblioteca',
            subtitulo: 'Os livros de Spurgeon, na Hoje e no Devocional.',
            valor: config.bibliotecaAtiva,
            salvando: _salvando.contains('bibliotecaAtiva'),
            aoMudar: (novo) => _alternar('bibliotecaAtiva', 'Biblioteca', novo),
          ),
        if (config.carregado)
          DevocionalInterruptor(
            titulo: 'Comentário no capítulo',
            subtitulo:
                'O comentário de Spurgeon abaixo de cada versículo da Bíblia.',
            valor: config.comentarioNoCapituloAtivo,
            salvando: _salvando.contains('comentarioNoCapituloAtivo'),
            aoMudar: (novo) => _alternar(
              'comentarioNoCapituloAtivo',
              'Comentário no capítulo',
              novo,
            ),
          ),
        const SizedBox(height: DevocionalEspacamento.sp24),
        const DevocionalFilete(largura: 64),
        const SizedBox(height: DevocionalEspacamento.sp16),
        if (config.emailsLegados.isNotEmpty) ...[
          Text(
            'A lista antiga ainda está no documento público, com '
            '${config.emailsLegados.length} e-mails. Migrar leva cada um para '
            'o próprio convite e apaga a lista.',
            style: tema.bodySmall,
          ),
          const SizedBox(height: DevocionalEspacamento.sp8),
          DevocionalBotaoPrimario(
            onPressed: _migrando ? null : _migrarConvidados,
            child: Text(_migrando ? 'Migrando...' : 'Migrar convidados'),
          ),
          const SizedBox(height: DevocionalEspacamento.sp16),
        ],
        StreamBuilder<List<String>>(
          // O bloco de migração acima entra e sai da lista: sem a chave, a
          // seção mudaria de índice e seria recriada, perdendo o e-mail
          // digitado.
          key: const ValueKey('convidados'),
          stream: _convidados,
          builder: (context, convidados) {
            if (convidados.hasError) {
              return Text(
                'Não foi possível carregar os convidados.',
                style: tema.bodyMedium,
              );
            }
            return DevocionalSecaoDeEmails(
              titulo: 'E-mails com conversas',
              legendaVazia: convidados.hasData
                  ? 'Ninguém liberado ainda.'
                  : 'Carregando os convidados...',
              legendaCheia: (n) =>
                  '$n ${n == 1 ? 'conta liberada' : 'contas liberadas'}.',
              emails: convidados.data ?? const [],
              textoDeRemocao: (email) => '$email perde o chat na hora.',
              aoAdicionar: ConfigAdmin.instancia.adicionarEmail,
              aoRemover: ConfigAdmin.instancia.removerEmail,
              contextoDeErro: 'Admin.convidados',
            );
          },
        ),
      ],
    );
  }
}
