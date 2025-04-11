// Pour Uint8List

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piper_tts_plugin/piper_tts_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelPiperTtsPlugin platform = MethodChannelPiperTtsPlugin();
  const MethodChannel channel = MethodChannel('piper_tts_plugin');

  // Mock handler pour les appels de méthode
  Future<dynamic> mockMethodCallHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'initializePiper':
        // Vérifier les arguments si nécessaire
        // final args = methodCall.arguments as Map?;
        // expect(args?['modelPath'], 'model.onnx');
        // expect(args?['configPath'], 'model.json');
        return true; // Simuler succès
      case 'synthesize':
        // Vérifier les arguments
        final args = methodCall.arguments as Map?;
        final text = args?['text'] as String?;
        if (text != null && text.isNotEmpty) {
          // Retourner des données audio simulées
          return Uint8List.fromList(List.generate(50, (index) => index.toUnsigned(8)));
        } else {
          return null; // Simuler null pour texte vide
        }
      case 'releasePiper':
        return null; // Simuler void
      default:
        return null;
    }
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      mockMethodCallHandler, // Utiliser le handler défini ci-dessus
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  // Remplacer le test getPlatformVersion par des tests pour les nouvelles méthodes
  test('initializePiper', () async {
    expect(await platform.initialize(modelPath: 'model.onnx', configPath: 'model.json'), true);
  });

  test('synthesize', () async {
    final result = await platform.synthesize(text: 'Bonjour');
    expect(result, isA<Uint8List>());
    expect(result?.length, 50); // Vérifier la taille simulée

    final nullResult = await platform.synthesize(text: '');
    expect(nullResult, isNull);
  });

  test('releasePiper', () async {
    await expectLater(platform.release(), completes);
  });
}
