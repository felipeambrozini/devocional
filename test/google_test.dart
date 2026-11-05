import 'package:devocional/dados/google.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('devocional/assinatura');
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Devocional',
      packageName: 'com.felipeambrozini.devocional',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() {
    mensageiro.setMockMethodCallHandler(canal, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('no Android prova a identidade com o pacote e o SHA-1', () async {
    mensageiro.setMockMethodCallHandler(
      canal,
      (chamada) async => chamada.method == 'sha1' ? 'ab12cd' : null,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(await cabecalhosGoogle(), {
      'Content-Type': 'application/json',
      'X-Android-Package': 'com.felipeambrozini.devocional',
      'X-Android-Cert': 'ab12cd',
    });
  });

  test('no iOS prova a identidade com o Bundle ID', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(await cabecalhosGoogle(), {
      'Content-Type': 'application/json',
      'X-Ios-Bundle-Identifier': 'com.felipeambrozini.devocional',
    });
  });

  test('sem o canal nativo segue sem a prova, sem lançar', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(await cabecalhosGoogle(), {'Content-Type': 'application/json'});
  });
}
