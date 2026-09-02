import '../data/recursos.dart';

/// As linhas do cartão "Como usar" da Hoje. A mesma ajuda reaparece em Sobre,
/// porque quem dispensou o cartão na primeira visita não tem como vê-lo de
/// novo — e o caminho para a ajuda não pode depender só do primeiro dia.
///
/// A linha sobre Conversas só entra para quem tem acesso à função (ver
/// [Recursos.conversas]): sem o filtro, quem abre "Ver tudo" em Sobre lia uma
/// instrução para uma aba que não existe para ele.
List<String> get linhasDeAjuda => [
  'Na Bíblia, deslize o dedo para virar o capítulo; com mouse e teclado, '
      'use as setas.',
  'O Devocional traz Manhã, Promessas e Noite, e vira sozinho com o horário.',
  '"Ler tudo" abre a leitura do dia inteira.',
  if (Recursos.conversas)
    'Na aba Conversas, o chat com Spurgeon e com Felipe: pergunte sobre a '
        'Palavra, peça uma aplicação, desabafe.',
  'O retrato de Spurgeon no começo do capítulo e da introdução lê o texto '
      'na voz dele: toque para ouvir, e toque de novo para encerrar.',
  'No computador, a tecla P também começa e encerra a leitura, e a barra de '
      'cima ganha um botão de parar enquanto ela toca.',
  'No Plano, marque o dia quando terminar a leitura.',
];
