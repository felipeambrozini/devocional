import 'package:flutter/material.dart';

/// As duas paletas: marrom e dourada no escuro, pergaminho e bronze no claro.
///
/// A clara não é a escura invertida. O dourado `#C9A227` sobre pergaminho dá
/// 2,1:1 e é ilegível: o que carrega a identidade num fundo claro é o mesmo
/// metal, mas escuro, e por isso o par de destaques vira bronze. A relação entre
/// os tons é que se mantém, não os valores.
///
/// Todo par abaixo foi conferido contra o fundo em que é usado. Os números estão
/// anotados porque é a única forma de a próxima pessoa saber que não pode
/// clarear o bronze "só um pouco" sem refazer a conta.
abstract final class DevocionalCores {
  // Escuro. Corpo em [bege] e não em dourado puro: dourado sobre marrom fica em
  // torno de 4:1, que cansa a vista num capítulo inteiro, e o bege chega a 11:1.
  static const fundo = Color(0xFF2E1B10);
  static const superficie = Color(0xFF3D2417);
  static const superficieAlta = Color(0xFF4A2E1D);
  static const dourado = Color(0xFFC9A227); // 6,8:1 sobre o fundo
  static const douradoClaro = Color(0xFFE3C567); // destaque, mais claro
  static const douradoEscuro = Color(0xFF8C6D1F); // traço e borda
  static const bege = Color(0xFFEDE0C8); // corpo, 11:1
  static const begeSuave = Color(0xFFC9B99A); // apoio, 8,5:1

  // Claro. A hierarquia espelha a de cima: o destaque é o tom mais distante do
  // fundo, que aqui quer dizer mais escuro em vez de mais claro.
  static const pergaminho = Color(0xFFF7F1E3);
  static const pergaminhoAlto = Color(0xFFFFFBF2);
  static const pergaminhoFundo = Color(0xFFEFE4CE);
  static const bronze = Color(0xFF7A5C12); // 5,5:1 sobre o pergaminho
  static const bronzeEscuro = Color(0xFF5E4409); // destaque, 8,1:1
  static const bronzeSuave = Color(0xFFC2AE86); // traço e borda
  static const tinta = Color(0xFF3D2417); // corpo, 12,8:1
  static const tintaSuave = Color(0xFF6B5842); // apoio, 6,0:1

  // Exceção isolada: marca do WhatsApp, só no gating premium de
  // `lib/telas/conversas.dart`. Não é acento do sistema — Regra do Metal
  // continua valendo, e nenhum outro FilledButton usa esta cor.
  static const whatsapp = Color(0xFF25D366);
}
