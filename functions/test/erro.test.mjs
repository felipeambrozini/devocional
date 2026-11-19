import assert from "node:assert/strict";
import {test} from "node:test";
import {
  chaveDoCliente,
  chaveDoErro,
  LimitadorDeTaxa,
  normalizarErro,
} from "../lib/erro.js";

const valido = {
  origem: "dart",
  contexto: "Nuvem.iniciar",
  mensagem: "Falha ao abrir a leitura",
  pilha: "Error: x\n    at main.dart:10",
  arquivo: "main.dart.js",
  linha: 10,
  url: "/devocional/hoje?pergunta=segredo#trecho",
  versao: "1.22.0",
  plataforma: "web",
};

test("normalizarErro aceita o contrato e tira query e fragmento da URL", () => {
  assert.deepEqual(normalizarErro(valido), {
    origem: "dart",
    contexto: "Nuvem.iniciar",
    mensagem: "Falha ao abrir a leitura",
    pilha: "Error: x\n    at main.dart:10",
    arquivo: "main.dart.js",
    linha: 10,
    url: "/devocional/hoje",
    versao: "1.22.0",
    plataforma: "web",
  });
});

test("normalizarErro recusa corpo vazio, array, origem desconhecida e sem mensagem", () => {
  assert.equal(normalizarErro(null), null);
  assert.equal(normalizarErro([]), null);
  assert.equal(normalizarErro("texto"), null);
  assert.equal(normalizarErro({...valido, origem: "outra"}), null);
  assert.equal(normalizarErro({...valido, mensagem: ""}), null);
  assert.equal(normalizarErro({...valido, mensagem: 42}), null);
});

test("normalizarErro corta tamanhos e remove caracteres de controle", () => {
  const normalizado = normalizarErro({
    ...valido,
    contexto: "c".repeat(200),
    mensagem: "a\u0000b".repeat(2000),
    pilha: "p".repeat(20000),
    arquivo: "f".repeat(1000),
    url: "/" + "u".repeat(1000),
    versao: "1".repeat(100),
    plataforma: "p".repeat(100),
  });
  assert.equal(normalizado.mensagem.length, 1000);
  assert.equal(normalizado.mensagem.includes("\u0000"), false);
  assert.equal(normalizado.contexto.length, 80);
  assert.equal(normalizado.pilha.length, 8000);
  assert.equal(normalizado.arquivo.length, 300);
  assert.equal(normalizado.url.length, 300);
  assert.equal(normalizado.versao.length, 40);
  assert.equal(normalizado.plataforma.length, 20);
});

test("normalizarErro zera linha inválida e descarta URL que não é caminho", () => {
  assert.equal(normalizarErro({...valido, linha: 1.5}).linha, 0);
  assert.equal(normalizarErro({...valido, linha: -3}).linha, 0);
  assert.equal(normalizarErro({...valido, linha: "10"}).linha, 0);
  assert.equal(normalizarErro({...valido, url: "https://exemplo/x"}).url, "");
});

test("normalizarErro tira query e fragmento também do arquivo", () => {
  const normalizado = normalizarErro({
    ...valido,
    arquivo: "https://www.felipeambrozini.com.br/devocional/main.dart.js?v=segredo#x",
  });
  assert.equal(normalizado.arquivo, "https://www.felipeambrozini.com.br/devocional/main.dart.js");
});

test("chaveDoErro é estável e separa falhas diferentes", () => {
  const dados = normalizarErro(valido);
  const chave = chaveDoErro(dados);
  assert.equal(chave, chaveDoErro(normalizarErro({...valido})));
  assert.equal(chave.length, 32);
  assert.notEqual(chave, chaveDoErro(normalizarErro({
    ...valido,
    mensagem: "Outra falha",
  })));
  assert.notEqual(chave, chaveDoErro(normalizarErro({
    ...valido,
    versao: "1.23.0",
  })));
  assert.notEqual(chave, chaveDoErro(normalizarErro({
    ...valido,
    contexto: "Outra área",
  })));
});

test("chaveDoCliente muda com o IP e com o sal, sem guardar o IP", () => {
  const ip = "203.0.113.7";
  const a = chaveDoCliente(ip, "sal-a");
  assert.equal(a, chaveDoCliente(ip, "sal-a"));
  assert.notEqual(a, chaveDoCliente(ip, "sal-b"));
  assert.notEqual(a, chaveDoCliente("203.0.113.8", "sal-a"));
  assert.equal(a.includes(ip), false);
});

test("LimitadorDeTaxa libera até o limite e reabre na janela seguinte", () => {
  const limitador = new LimitadorDeTaxa(2, 60_000);
  assert.equal(limitador.permitir("a", 0), true);
  assert.equal(limitador.permitir("a", 10), true);
  assert.equal(limitador.permitir("a", 20), false);
  assert.equal(limitador.permitir("b", 20), true);
  assert.equal(limitador.permitir("a", 60_000), true);
  assert.equal(limitador.permitir("a", 60_001), true);
  assert.equal(limitador.permitir("a", 60_002), false);
});
