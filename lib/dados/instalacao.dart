/// Instalar a versão web como app (PWA): ícone na tela inicial, janela
/// própria, sem passar por loja.
///
/// O navegador decide sozinho quando um site pode ser instalado. No Chrome e
/// no Edge ele avisa com o evento `beforeinstallprompt`, que o `index.html`
/// guarda em `window.convitePraInstalar` antes do Flutter carregar (o evento
/// costuma chegar antes do primeiro quadro). Com o convite em mãos,
/// [InstalacaoDoApp.pedir] abre a janela de instalação do próprio navegador.
/// Safari (iPhone e Mac) e Firefox não mandam convite: ali só resta explicar
/// o caminho pelo menu, o que `TabernaculoItemDeInstalar` faz.
///
/// Mesma costura condicional de `url_da_pagina.dart`: na web a implementação
/// de verdade (`instalacao_web.dart`); no Android, no iOS e nos testes,
/// `instalacao_io.dart`, que nunca oferece nada (o app nativo já é app).
library;

import 'package:flutter/foundation.dart';

import 'instalacao_io.dart'
    if (dart.library.js_interop) 'instalacao_web.dart'
    as plataforma;

/// No iPhone e no iPad, o Safari só entrega Web Push a site instalado na tela
/// de início (iOS 16.4+), e a permissão só pode ser pedida de dentro do app
/// instalado. Fora dele, ligar os lembretes falha, e a única saída é
/// instalar: a folha de ajustes troca o interruptor por esse convite.
/// [plataforma] é o sistema do aparelho (na web, o Flutter tira do
/// navegador); fora da web [InstalacaoDoApp.disponivel] já é falso.
bool lembretesPedemInstalar(
  InstalacaoDoApp instalacao,
  TargetPlatform plataforma,
) => instalacao.disponivel && plataforma == TargetPlatform.iOS;

abstract class InstalacaoDoApp extends ChangeNotifier {
  /// A da plataforma em que o app está rodando. Os testes passam a própria
  /// ao widget em vez de trocar esta.
  static final InstalacaoDoApp instancia = plataforma.criarInstalacao();

  /// Faz sentido oferecer a instalação: é a web e o app não está aberto como
  /// app instalado (nem acabou de ser instalado nesta aba).
  bool get disponivel;

  /// O navegador mandou o convite, e [pedir] abre a janela dele. Sem
  /// convite, só as instruções pelo menu.
  bool get temConviteDoNavegador;

  /// Abre a janela de instalação do navegador. Devolve `true` se a pessoa
  /// aceitou. O convite só serve uma vez: depois disso
  /// [temConviteDoNavegador] fica falso até o navegador mandar outro. Se a
  /// janela do navegador falhar, lança: quem chama mostra o caminho pelo
  /// menu.
  Future<bool> pedir();
}
