import assert from "node:assert/strict";
import {test} from "node:test";
import {
  atrasoMinutos,
  calcularProximoEnvio,
  deveEnviar,
  referenciaDoSlot,
} from "../lib/regras.js";

test("atrasoMinutos dá a volta na meia-noite", () => {
  assert.equal(atrasoMinutos(3, 23 * 60 + 55), 8);
  assert.equal(atrasoMinutos(600, 600), 0);
  assert.equal(atrasoMinutos(599, 600), 1439);
});

test("deveEnviar respeita tolerância e envio do dia", () => {
  assert.equal(deveEnviar(660, 600, undefined, "2026-01-01"), true);
  assert.equal(deveEnviar(661, 600, undefined, "2026-01-01"), false);
  assert.equal(deveEnviar(660, 600, "2026-01-01", "2026-01-01"), false);
});

test("referenciaDoSlot usa ontem quando o atraso veio da volta", () => {
  assert.deepEqual(referenciaDoSlot("2026-03-01", 5, 23 * 60 + 30),
      {diaISO: "2026-02-28", diaChave: "28-02"});
  assert.deepEqual(referenciaDoSlot("2028-03-01", 5, 23 * 60 + 30),
      {diaISO: "2028-02-29", diaChave: "29-02"});
  assert.deepEqual(referenciaDoSlot("2026-01-01", 5, 23 * 60 + 30),
      {diaISO: "2025-12-31", diaChave: "31-12"});
  assert.deepEqual(referenciaDoSlot("2026-03-01", 700, 600),
      {diaISO: "2026-03-01", diaChave: "01-03"});
});

function simularEnvios(alvoMinuto, dias) {
  const envios = [];
  let ultimoEnvio;
  const inicio = Date.UTC(2026, 0, 1, 12);
  for (let minuto = 0; minuto < dias * 1440; minuto++) {
    const agora = new Date(inicio + minuto * 60000);
    const diaISO = agora.toISOString().slice(0, 10);
    const minutoDoDia = agora.getUTCHours() * 60 + agora.getUTCMinutes();
    const slot = referenciaDoSlot(diaISO, minutoDoDia, alvoMinuto);
    if (deveEnviar(minutoDoDia, alvoMinuto, ultimoEnvio, slot.diaISO)) {
      envios.push({minutoDoDia, referencia: slot.diaISO});
      ultimoEnvio = slot.diaISO;
    }
  }
  return envios;
}

for (const [rotulo, alvo] of [["23:30", 1410], ["22:59", 1379], ["06:00", 360]]) {
  test(`um envio por dia, no horário, para o alvo ${rotulo}`, () => {
    const envios = simularEnvios(alvo, 3);
    assert.equal(envios.length, 3);
    for (const envio of envios) assert.equal(envio.minutoDoDia, alvo);
    assert.equal(new Set(envios.map((e) => e.referencia)).size, 3);
  });
}

test("proximoEnvio fica no futuro, a no máximo 60 min, e reenvio é em 1 min", () => {
  const base = Date.UTC(2026, 0, 1);
  for (let minuto = 0; minuto < 1440; minuto++) {
    for (const segundo of [0, 30]) {
      const agora = new Date(base + minuto * 60000 + segundo * 1000);
      const proximo = calcularProximoEnvio(agora, minuto, [360, 1410], false);
      assert.ok(proximo > agora);
      assert.ok(proximo - agora <= 60 * 60000);
    }
  }
  const agora = new Date(base + 10 * 60000 + 20000);
  assert.equal(calcularProximoEnvio(agora, 10, [360], true) - agora, 40000);
  assert.equal(calcularProximoEnvio(agora, 10, [], false) - agora, 60 * 60000 - 20000);
});

test("proximoEnvio aponta para o slot quando ele está a menos de 60 min", () => {
  const agora = new Date(Date.UTC(2026, 0, 1, 5, 40));
  const proximo = calcularProximoEnvio(agora, 340, [360], false);
  assert.equal(proximo.getTime() - agora.getTime(), 20 * 60000);
});
