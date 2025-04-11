import 'dart:convert'; // Pour jsonEncode
// Pour Uint8List

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaldi_gop_plugin/kaldi_gop_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelKaldiGopPlugin platform = MethodChannelKaldiGopPlugin();
  const MethodChannel channel = MethodChannel('kaldi_gop_plugin');

  // Mock handler pour les appels de méthode
  Future<dynamic> mockMethodCallHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'initializeKaldi':
        // final args = methodCall.arguments as Map?;
        // expect(args?['modelDir'], 'path/to/models');
        return true; // Simuler succès
      case 'calculateGop':
        // final args = methodCall.arguments as Map?;
        // expect(args?['audioData'], isA<Uint8List>());
        // expect(args?['referenceText'], 'mock text');
        // Retourner un JSON String simulé
        final mockResult = {
          "overall_score": 90.1,
          "words": [{"word": "test", "score": 90.1, "phonemes": []}]
        };
        return jsonEncode(mockResult);
      case 'releaseKaldi':
        return null; // Simuler void
      default:
        return null;
    }
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      mockMethodCallHandler,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  // Remplacer le test getPlatformVersion par des tests pour les nouvelles méthodes
  test('initializeKaldi', () async {
    expect(await platform.initialize(modelDir: 'path/to/models'), true);
  });

  test('calculateGop', () async {
    final resultJson = await platform.calculateGop(
        audioData: Uint8List(0), referenceText: 'mock text');
    expect(resultJson, isA<String>());
    // Décoder pour vérifier le contenu (optionnel)
    final decoded = jsonDecode(resultJson!);
    expect(decoded['overall_score'], 90.1);
  });

  test('releaseKaldi', () async {
    await expectLater(platform.release(), completes);
  });
}
