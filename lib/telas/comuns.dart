import 'package:flutter/material.dart';

import '../theme.dart';

/// Cartão com título em Cinzel dourado. Repete em quase toda tela.
class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    this.titulo,
    this.acessorio,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String? titulo;
  final Widget? acessorio;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(titulo!, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  ?acessorio,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// FutureBuilder que cria o future uma vez e só o refaz quando [chave] muda.
///
/// Escrever `FutureBuilder(future: Conteudo.instancia.algo(...))` dentro do `build`
/// entrega um future novo a cada redesenho, porque função `async` devolve outro
/// objeto Future a cada chamada, ainda que os dados já estejam em memória. O
/// FutureBuilder compara por identidade, vê um future diferente e volta ao estado de
/// carregando. Como toda tela lê o Estado, e o Estado notifica a árvore inteira,
/// favoritar um versículo redesenhava a tela da Bíblia e o capítulo inteiro virava
/// um spinner por um frame. Aqui o future nasce no initState e sobrevive aos
/// redesenhos.
///
/// [chave] é o que identifica o pedido: mudou a chave, mudou o pedido, e só então o
/// future é refeito. É a mesma ideia dos ValueKey que já marcavam esses
/// FutureBuilder, agora decidindo o que importa em vez de só trocar o State.
///
/// Não memoizar dentro do [Conteudo]: guardar o Future amarra ele à zona de quem
/// chamou primeiro, e um future criado no `tester.runAsync` nunca entrega o valor
/// para quem se inscreve pela zona de tempo falso do teste.
class CarregaUmaVez<T> extends StatefulWidget {
  const CarregaUmaVez({
    super.key,
    required this.chave,
    required this.carregar,
    required this.construir,
  });

  final String chave;
  final Future<T> Function() carregar;
  final AsyncWidgetBuilder<T> construir;

  @override
  State<CarregaUmaVez<T>> createState() => _CarregaUmaVezState<T>();
}

class _CarregaUmaVezState<T> extends State<CarregaUmaVez<T>> {
  late Future<T> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = widget.carregar();
  }

  @override
  void didUpdateWidget(CarregaUmaVez<T> anterior) {
    super.didUpdateWidget(anterior);
    if (widget.chave != anterior.chave) _futuro = widget.carregar();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<T>(future: _futuro, builder: widget.construir);
}

/// Filete dourado usado para separar seções sem o peso de um Divider comum.
class Filete extends StatelessWidget {
  const Filete({super.key, this.largura = 48});

  final double largura;

  @override
  Widget build(BuildContext context) => Container(
        width: largura,
        height: 2,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Cores.dourado, Cores.douradoEscuro],
          ),
          borderRadius: BorderRadius.circular(1),
        ),
      );
}

/// Estado de "ainda não há texto para isto", em vez de uma tela em branco.
class AvisoVazio extends StatelessWidget {
  const AvisoVazio({super.key, required this.icone, required this.titulo, this.detalhe});

  final IconData icone;
  final String titulo;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 44, color: Cores.douradoEscuro),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (detalhe != null) ...[
              const SizedBox(height: 8),
              Text(
                detalhe!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Editor de nota de um versículo. Devolve o texto salvo, ou nulo se cancelado.
Future<String?> editarNota(
  BuildContext context, {
  required String referencia,
  required String notaAtual,
}) {
  final controle = TextEditingController(text: notaAtual);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(referencia, style: Theme.of(context).textTheme.headlineSmall),
      content: TextField(
        controller: controle,
        autofocus: true,
        maxLines: 6,
        minLines: 3,
        decoration: const InputDecoration(hintText: 'Sua anotação'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controle.text),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// Nomes dos meses, usados no cronograma e no calendário.
const meses = <String>[
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

String dataLonga(DateTime data) => '${data.day} de ${meses[data.month - 1].toLowerCase()}';
