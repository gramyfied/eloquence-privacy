// Pour Uint8List

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_stt_plugin/whisper_stt_plugin.dart'; // Pour WhisperTranscriptionResult
import 'package:whisper_stt_plugin/whisper_stt_plugin_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelWhisperSttPlugin platform = MethodChannelWhisperSttPlugin();
  const MethodChannel channel = MethodChannel('whisper_stt_plugin');

  // Mock handler pour les appels de méthode
  Future<dynamic> mockMethodCallHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'initialize':
        // Vérifier les arguments si nécessaire
        // final args = methodCall.arguments as Map?;
        // expect(args?['modelPath'], 'path/to/model.bin');
        return true; // Simuler succès
      case 'transcribeChunk':
        // Vérifier les arguments si nécessaire
        // final args = methodCall.arguments as Map?;
        // expect(args?['audioChunk'], isA<Uint8List>());
        // Retourner une Map simulant le résultat
        return <String, dynamic>{
          'text': 'mock transcription',
          'isPartial': false,
          'confidence': 0.95,
        };
      case 'release':
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
    // TODO: Configurer un mock handler pour l'EventChannel si nécessaire pour tester les événements
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  // Remplacer le test getPlatformVersion par des tests pour les nouvelles méthodes
  test('initialize', () async {
    expect(await platform.initialize(modelPath: 'path/to/model.bin'), true);
  });

  test('transcribeChunk', () async {
    final result = await platform.transcribeChunk(audioChunk: Uint8List(0));
    expect(result, isA<WhisperTranscriptionResult>());
    expect(result.text, 'mock transcription');
    expect(result.isPartial, false);
    expect(result.confidence, 0.95);
  });

  test('release', () async {
    await expectLater(platform.release(), completes);
  });

  // TODO: Ajouter des tests pour le Stream transcriptionEvents si nécessaire
  // (nécessite de mocker l'EventChannel)
}
