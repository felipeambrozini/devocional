// Lógica de agendamento dos lembretes sem rede nem Firebase: a decisão de
// enviar do script (`tool/enviar_lembretes.dart`, importado por caminho
// relativo porque fica fora de lib/) e a regra anti-duplicata do app
// (`pushAindaVale` em lib/data/lembretes.dart).
import 'package:felipe_ambrozini/data/lembretes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/enviar_lembretes.dart'
    show atrasoEmMinutos, deveEnviarLembrete, toleranciaDeAtrasoMinutos;

void main() {
  group('atrasoEmMinutos (script)', () {
    test('no horário exato, zero', () {
      expect(atrasoEmMinutos(360, 360), 0);
    });

    test('depois do alvo no mesmo dia, conta direto', () {
      expect(atrasoEmMinutos(367, 360), 7);
    });

    test('antes do alvo no mesmo dia, volta pelo fim do dia anterior', () {
      // Alvo 06:00, agora 05:50: não é "atrasado", é cedo — o número alto é
      // justamente o que faz deveEnviarLembrete recusar.
      expect(atrasoEmMinutos(350, 360), 1430);
    });

    test('virada da meia-noite: alvo 23:55, agora 00:03 → 8', () {
      expect(atrasoEmMinutos(3, 1435), 8);
    });
  });

  group('deveEnviarLembrete (script)', () {
    const hoje = '2026-08-22';

    test('no horário e nunca enviado, envia', () {
      expect(
        deveEnviarLembrete(
          agoraMinutoDoDia: 360,
          alvoMinutoDoDia: 360,
          ultimoEnvio: null,
          hoje: hoje,
        ),
        isTrue,
      );
    });

    test('atraso dentro da janela (o cron do GitHub atrasa), envia', () {
      expect(
        deveEnviarLembrete(
          agoraMinutoDoDia: 385,
          alvoMinutoDoDia: 360,
          ultimoEnvio: null,
          hoje: hoje,
        ),
        isTrue,
      );
    });

    test('no limite da janela ($toleranciaDeAtrasoMinutos min), envia', () {
      expect(
        deveEnviarLembrete(
          agoraMinutoDoDia: 360 + toleranciaDeAtrasoMinutos,
          alvoMinutoDoDia: 360,
          ultimoEnvio: null,
          hoje: hoje,
        ),
        isTrue,
      );
    });

    test('além da janela, não envia — nem vira spam na rodada seguinte', () {
      expect(
        deveEnviarLembrete(
          agoraMinutoDoDia: 360 + toleranciaDeAtrasoMinutos + 1,
          alvoMinutoDoDia: 360,
          ultimoEnvio: null,
          hoje: hoje,
        ),
        isFalse,
      );
    });

    test('antes do horário de hoje, não envia adiantado', () {
      expect(
        deveEnviarLembrete(
          agoraMinutoDoDia: 300,
          alvoMinutoDoDia: 360,
          ultimoEnvio: null,
          hoje: hoje,
        ),
        isFalse,
      );
    });

    test('já enviado hoje, não envia de novo (rodada seguinte da janela)', () {
      expect(
        deveEnviarLembrete(
          agoraMinutoDoDia: 365,
          alvoMinutoDoDia: 360,
          ultimoEnvio: hoje,
          hoje: hoje,
        ),
        isFalse,
      );
    });

    test('enviado ontem, envia hoje quando chegar a hora', () {
      expect(
        deveEnviarLembrete(
          agoraMinutoDoDia: 362,
          alvoMinutoDoDia: 360,
          ultimoEnvio: '2026-08-21',
          hoje: hoje,
        ),
        isTrue,
      );
    });

    test('virada da meia-noite perto do alvo, ainda conta como atraso curto', () {
      expect(
        deveEnviarLembrete(
          agoraMinutoDoDia: 3,
          alvoMinutoDoDia: 1439,
          ultimoEnvio: null,
          hoje: hoje,
        ),
        isTrue,
      );
    });
  });

  group('pushAindaVale (app)', () {
    test('push em cima do horário vale', () {
      expect(pushAindaVale(minutoAgora: 360, minutoAlvo: 360), isTrue);
    });

    test('dentro da janela do fallback ($atrasoDoFallbackMinutos min), vale', () {
      expect(pushAindaVale(minutoAgora: 364, minutoAlvo: 360), isTrue);
    });

    test('depois da janela, o alarme local já avisou — push vira duplicata', () {
      expect(pushAindaVale(minutoAgora: 367, minutoAlvo: 360), isFalse);
    });

    test('virada da meia-noite segue a mesma régua', () {
      // Alvo 23:58, agora 00:04: 6 min de atraso, além da janela.
      expect(pushAindaVale(minutoAgora: 4, minutoAlvo: 1438), isFalse);
    });
  });
}
