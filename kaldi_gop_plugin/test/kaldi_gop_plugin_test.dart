import 'dart:convert'; // Pour jsonEncode
import 'dart:typed_data'; // Pour Uint8List

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:kaldi_gop_plugin/kaldi_gop_plugin.dart';
import 'package:kaldi_gop_plugin/kaldi_gop_plugin_platform_interface.dart';
import 'package:kaldi_gop_plugin/kaldi_gop_plugin_method_channel.dart';


class MockKaldiGopPluginPlatform
    with MockPlatformInterfaceMixin
    implements KaldiGopPluginPlatform {

  // Mock implementations for the new methods
  @override
  Future<bool> initialize({required String modelDir}) async => true; // Simule succès

  @override
  Future<String?> calculateGop({
    required Uint8List audioData,
    required String referenceText,
  }) async {
    // Simuler un retour JSON
    if (referenceText.isNotEmpty) {
      final mockResult = {
        "overall_score": 85.2,
        "words": [
          {"word": "mock", "score": 90.0, "phonemes": []},
          {"word": "result", "score": 80.0, "phonemes": []}
        ]
      };
      return jsonEncode(mockResult);
    } else {
      return null; // Simuler une erreur pour texte vide
    }
  }

  @override
  Future<void> release() async {} // Simule void
}

void main() {
  final KaldiGopPluginPlatform initialPlatform = KaldiGopPluginPlatform.instance;

  test('$MethodChannelKaldiGopPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelKaldiGopPlugin>());
  });

  // Remplacer le test getPlatformVersion par des tests pour les nouvelles méthodes
  test('initialize', () async {
    KaldiGopPlugin kaldiGopPlugin = KaldiGopPlugin();
    MockKaldiGopPluginPlatform fakePlatform = MockKaldiGopPluginPlatform();
    KaldiGopPluginPlatform.instance = fakePlatform;

    expect(await kaldiGopPlugin.initialize(modelDir: 'path/to/models'), true);
  });

  test('calculateGop', () async {
    KaldiGopPlugin kaldiGopPlugin = KaldiGopPlugin();
    MockKaldiGopPluginPlatform fakePlatform = MockKaldiGopPluginPlatform();
    KaldiGopPluginPlatform.instance = fakePlatform;

    final result = await kaldiGopPlugin.calculateGop(
        audioData: Uint8List(0), referenceText: 'mock text');
    expect(result, isA<KaldiGopResult>());
    expect(result?.overallScore, 85.2);
    expect(result?.words.length, 2);
    expect(result?.words[0].word, 'mock');

    final nullResult = await kaldiGopPlugin.calculateGop(
        audioData: Uint8List(0), referenceText: '');
    expect(nullResult, isNull);
  });

   test('release', () async {
     KaldiGopPlugin kaldiGopPlugin = KaldiGopPlugin();
     MockKaldiGopPluginPlatform fakePlatform = MockKaldiGopPluginPlatform();
     KaldiGopPluginPlatform.instance = fakePlatform;

     // Vérifier qu'aucune exception n'est levée
     await expectLater(kaldiGopPlugin.release(), completes);
   });
}
