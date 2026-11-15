import 'instalacao.dart';

/// Fora da web não há o que instalar: o app nativo já é app. A fachada
/// condicional (`instalacao.dart`) cai aqui no Android, no iOS e nos testes.
InstalacaoDoApp criarInstalacao() => _SemInstalacao();

class _SemInstalacao extends InstalacaoDoApp {
  @override
  bool get disponivel => false;

  @override
  bool get temConviteDoNavegador => false;

  @override
  Future<bool> pedir() async => false;
}
