import 'package:flutter/material.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import 'widgets.dart';

/// Primeira visita: o retrato, o nome e a fala de boas-vindas da persona, no
/// lugar da lista vazia.
class DevocionalBoasVindas extends StatelessWidget {
  const DevocionalBoasVindas({super.key, required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cor.primary, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(DevocionalEspacamento.sp2),
                child: ClipOval(
                  child: Image.asset(
                    persona.foto,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            const SizedBox(height: DevocionalEspacamento.sp18),
            // A carta de boas-vindas também é página: abre pelo DevocionalFilete, como
            // toda leitura da Estante.
            const DevocionalFilete(largura: 64),
            const SizedBox(height: DevocionalEspacamento.sp12),
            Text(persona.nome, style: tema.headlineSmall),
            const SizedBox(height: DevocionalEspacamento.sp10),
            Text(
              persona.boasVindas,
              textAlign: TextAlign.center,
              style: tema.bodyLarge?.copyWith(
                color: cor.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: DevocionalEspacamento.sp16),
            // A divulgação se repete aqui, fora do rodapé: quem lê a carta de
            // boas-vindas ainda não chegou ao campo de escrever, e o aviso de
            // que a resposta é gerada não pode aparecer só depois do convite.
            Text(
              avisoDeIa,
              style: tema.labelMedium?.copyWith(color: cor.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
