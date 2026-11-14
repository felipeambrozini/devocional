import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/registro.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import 'botao.dart';

/// A allowlist do chat no painel: título, contagem, campo de adicionar e a
/// lista com remover.
class DevocionalSecaoDeEmails extends StatefulWidget {
  const DevocionalSecaoDeEmails({
    super.key,
    required this.titulo,
    required this.legendaVazia,
    required this.legendaCheia,
    required this.emails,
    required this.textoDeRemocao,
    required this.aoAdicionar,
    required this.aoRemover,
    required this.contextoDeErro,
  });

  final String titulo;
  final String legendaVazia;
  final String Function(int total) legendaCheia;
  final List<String> emails;
  final String Function(String email) textoDeRemocao;
  final Future<void> Function(String email) aoAdicionar;
  final Future<void> Function(String email) aoRemover;
  final String contextoDeErro;

  @override
  State<DevocionalSecaoDeEmails> createState() =>
      _DevocionalSecaoDeEmailsState();
}

class _DevocionalSecaoDeEmailsState extends State<DevocionalSecaoDeEmails> {
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
                autofocus: true,
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Adicionando',
                      ),
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
            title: Text(email),
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
