import 'package:flutter/material.dart';

import 'data/estado.dart';
import 'telas/biblia.dart';
import 'telas/devocional.dart';
import 'telas/hoje.dart';
import 'telas/notas.dart';
import 'telas/plano.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final estado = await Estado.abrir();
  runApp(AppDevocional(estado: estado));
}

class AppDevocional extends StatelessWidget {
  const AppDevocional({super.key, required this.estado});

  final Estado estado;

  @override
  Widget build(BuildContext context) {
    return EscopoDoEstado(
      estado: estado,
      child: MaterialApp(
        title: 'Devocional',
        debugShowCheckedModeBanner: false,
        theme: construirTema(),
        home: const Moldura(),
      ),
    );
  }
}

class _Destino {
  const _Destino(this.rotulo, this.icone, this.iconeAtivo, this.tela);

  final String rotulo;
  final IconData icone;
  final IconData iconeAtivo;
  final Widget tela;
}

const _destinos = <_Destino>[
  _Destino('Hoje', Icons.wb_twilight_outlined, Icons.wb_twilight, TelaHoje()),
  _Destino('Bíblia', Icons.menu_book_outlined, Icons.menu_book, TelaBiblia()),
  _Destino('Devocional', Icons.auto_stories_outlined, Icons.auto_stories, TelaDevocional()),
  _Destino('Plano', Icons.event_note_outlined, Icons.event_note, TelaPlano()),
  _Destino('Notas', Icons.bookmark_outline, Icons.bookmark, TelaNotas()),
];

/// Casca de navegação. Barra inferior no celular, trilho lateral em tela larga.
/// O corte em 720 px é onde cinco rótulos deixam de caber com folga na horizontal.
class Moldura extends StatefulWidget {
  const Moldura({super.key});

  @override
  State<Moldura> createState() => _MolduraState();
}

class _MolduraState extends State<Moldura> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 720;

    // IndexedStack preserva a posição de rolagem e o capítulo aberto ao alternar
    // de aba, que é o que se espera de um app de leitura.
    final corpo = IndexedStack(
      index: _indice,
      children: [for (final d in _destinos) d.tela],
    );

    if (!largo) {
      return Scaffold(
        body: corpo,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: (i) => setState(() => _indice = i),
          destinations: [
            for (final d in _destinos)
              NavigationDestination(
                icon: Icon(d.icone),
                selectedIcon: Icon(d.iconeAtivo),
                label: d.rotulo,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _indice,
            onDestinationSelected: (i) => setState(() => _indice = i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinos)
                NavigationRailDestination(
                  icon: Icon(d.icone),
                  selectedIcon: Icon(d.iconeAtivo),
                  label: Text(d.rotulo),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: corpo),
        ],
      ),
    );
  }
}
