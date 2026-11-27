import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Onde mora o texto da SIL Open Font License 1.1, igual para as duas fontes.
const caminhoDaOfl = 'assets/licencas/OFL.txt';

/// As fontes empacotadas (`fonts:` no pubspec) e o aviso de copyright de cada
/// uma, tirado do próprio arquivo da fonte (tabela `name`, id 0).
///
/// A OFL só deixa redistribuir a fonte com o aviso e a licença junto. As
/// dependências do pub (Font Awesome incluso, com o crédito CC BY dos ícones
/// no LICENSE do pacote) entram sozinhas na página de licenças; as fontes
/// copiadas para `assets/fontes/` não, por isso o registro abaixo. Fonte nova
/// no pubspec entra aqui também (o teste de licenças confere).
const fontesComOfl = {
  'Cinzel':
      'Copyright 2020 The Cinzel Project Authors '
      '(https://github.com/NDISCOVER/Cinzel)',
  'Montserrat':
      'Copyright 2011 The Montserrat Project Authors '
      '(https://github.com/JulietaUla/Montserrat)',
};

/// Põe as fontes na página de licenças (Sobre → Licenças de código aberto).
///
/// O [LicenseRegistry] só chama o coletor quando alguém abre a página, então
/// o asset não é lido na abertura do app. [pacote] existe para os testes.
void registrarLicencasDasFontes({AssetBundle? pacote}) {
  LicenseRegistry.addLicense(() async* {
    final ofl = await (pacote ?? rootBundle).loadString(caminhoDaOfl);
    for (final MapEntry(key: fonte, value: copyright) in fontesComOfl.entries) {
      yield LicenseEntryWithLineBreaks([fonte], '$copyright\n\n$ofl');
    }
  });
}
