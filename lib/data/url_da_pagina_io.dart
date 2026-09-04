/// No-op fora da web: sem barra de endereço, não há o que limpar. A fachada
/// condicional (`url_da_pagina.dart`) cai aqui no Android, iOS e nos testes.
void removerParametroDaUrl(String chave) {}
