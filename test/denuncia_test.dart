import 'package:devocional/dados/denuncias.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/personas.dart';
import 'package:devocional/funcoes/aviso.dart';
import 'package:devocional/telas/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Mensagem mensagem(String id, String papel, String texto) =>
    Mensagem(id: id, papel: papel, texto: texto, momento: 1);

void main() {
  test('denunciaDaResposta leva o par pergunta/resposta e corta os tetos', () {
    final denuncia = denunciaDaResposta(
      resposta: mensagem('m2', Mensagem.papelAssistente, 'r' * 40000),
      pergunta: mensagem('m1', Mensagem.papelUsuario, 'p' * 25000),
      persona: personaSpurgeon.id,
      conversaId: 'c1',
      motivo: 'doutrina',
      detalhe: 'd' * 2000,
    );
    final json = denuncia.paraJson(
      uid: 'alice',
      criadoEm: 'agora',
      versao: '1.22.0+47',
      plataforma: 'web-android',
    );

    expect(json['uid'], 'alice');
    expect(json['persona'], 'spurgeon');
    expect(json['conversaId'], 'c1');
    expect(json['mensagemId'], 'm2');
    expect(json['motivo'], 'doutrina');
    expect(json['pergunta'], hasLength(20000));
    expect(json['resposta'], hasLength(30000));
    expect(json['detalhe'], hasLength(1000));
    expect(json['versao'], '1.22.0+47');
    expect(json['plataforma'], 'web-android');
  });

  test(
    'denunciaDaResposta aceita resposta sem pergunta (conversa cortada)',
    () {
      final denuncia = denunciaDaResposta(
        resposta: mensagem('m2', Mensagem.papelAssistente, 'resposta'),
        persona: personaSpurgeon.id,
        conversaId: null,
        motivo: 'outro',
      );
      expect(denuncia.pergunta, '');
      expect(denuncia.conversaId, '');
    },
  );

  testWidgets('o portão de idade é a primeira coisa do chat e fica guardado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final estado = Estado(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: estado,
          child: TelaChat(persona: personaSpurgeon),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Antes de conversar'), findsOneWidget);
    expect(find.text('Tenho 18 anos ou mais'), findsOneWidget);
    // Nem campo de mensagem nem aviso de IA antes da declaração.
    expect(find.text(avisoDeIa), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Tenho 18 anos ou mais'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Antes de conversar'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(estado.maiorDeIdade, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('maior_de_idade'), isTrue);
  });

  testWidgets(
    'a resposta da IA pode ser denunciada com a pergunta de contexto',
    (tester) async {
      SharedPreferences.setMockInitialValues({'maior_de_idade': true});
      final estado = Estado(await SharedPreferences.getInstance());
      final conversa = await estado.novaConversa(
        personaSpurgeon.id,
        titulo: 'O que é fé?',
      );
      await estado.registrarMensagem(
        personaSpurgeon.id,
        conversa.id,
        mensagem('m1', Mensagem.papelUsuario, 'O que é fé?'),
      );
      await estado.registrarMensagem(
        personaSpurgeon.id,
        conversa.id,
        mensagem('m2', Mensagem.papelAssistente, 'Fé é a certeza das coisas.'),
      );

      Denuncia? capturada;
      final enviadorOriginal = Denuncias.enviador;
      Denuncias.enviador = (denuncia) async => capturada = denuncia;
      addTearDown(() => Denuncias.enviador = enviadorOriginal);

      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: estado,
            child: TelaChat(persona: personaSpurgeon, conversaId: conversa.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Só a resposta tem o botão; a pergunta do visitante não.
      expect(find.text('Denunciar resposta'), findsOneWidget);

      await tester.tap(find.text('Denunciar resposta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Denunciar resposta'), findsWidgets);

      await tester.tap(find.text('Informação bíblica errada'));
      await tester.pump();
      await tester.tap(find.text('Enviar denúncia'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(capturada, isNotNull);
      expect(capturada!.motivo, 'doutrina');
      expect(capturada!.persona, personaSpurgeon.id);
      expect(capturada!.conversaId, conversa.id);
      expect(capturada!.mensagemId, 'm2');
      expect(capturada!.pergunta, 'O que é fé?');
      expect(capturada!.resposta, 'Fé é a certeza das coisas.');
      expect(
        find.text('Denúncia enviada. Obrigado por avisar.'),
        findsOneWidget,
      );

      // O aviso agenda o próprio fechamento (ver aviso.dart); sem avançar o
      // relógio falso, o timer fica pendente na verificação do teste.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
