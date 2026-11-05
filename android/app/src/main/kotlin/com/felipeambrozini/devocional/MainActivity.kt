package com.felipeambrozini.devocional

import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * Expõe o SHA-1 da assinatura do apk para cabecalhosGoogle() em
 * lib/dados/google.dart: a chave de API do Google restrita ao app confere
 * pacote + SHA-1 no cabeçalho X-Android-Cert de todo pedido.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "devocional/assinatura")
            .setMethodCallHandler { chamada, resposta ->
                if (chamada.method == "sha1") resposta.success(sha1DaAssinatura())
                else resposta.notImplemented()
            }
    }

    // Hex minúsculo sem separadores: o formato que o Google aceita no cabeçalho.
    private fun sha1DaAssinatura(): String? =
        assinaturaDoApk()?.let { assinatura ->
            MessageDigest.getInstance("SHA-1")
                .digest(assinatura.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }

    // GET_SIGNATURES e getPackageInfo(String, Int) são as únicas APIs abaixo
    // do Android 9 e 13, respectivamente, e o minSdk do app é 24.
    @Suppress("DEPRECATION")
    private fun assinaturaDoApk(): Signature? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                .signatures?.firstOrNull()
        }
}
