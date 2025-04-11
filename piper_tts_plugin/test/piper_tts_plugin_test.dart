import 'package:flutter_test/flutter_test.dart';
import 'package:piper_tts_plugin/piper_tts_plugin.dart';
import 'package:piper_tts_plugin/piper_tts_plugin_platform_interface.dart';
import 'package:piper_tts_plugin/piper_tts_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dart:typed_data'; // Pour Uint8List

class MockPiperTtsPluginPlatform
    with MockPlatformInterfaceMixin
    implements PiperTtsPluginPlatform {

  // Mock implementations for the new methods
  @override
  Future<bool> initialize({
    required String modelPath,
    required String configPath,
  }) async => true; // Simule succès

  @override
  Future<Uint8List?> synthesize({required String text}) async {
    // Simuler un retour audio (ex: quelques bytes de silence)
    if (text.isNotEmpty) {
      return Uint8List.fromList(List.generate(100, (index) => 0));
    } else {
      return null; // Simuler une erreur ou pas d'audio pour texte vide
    }
  }

  @override
  Future<void> release() async {} // Simule void

  // Mock Stream (si nécessaire)
  // final StreamController<PiperTtsEvent> _streamController = StreamController.broadcast();
  // @override
  // Stream<PiperTtsEvent> get synthesisEvents => _streamController.stream;
}

void main() {
  final PiperTtsPluginPlatform initialPlatform = PiperTtsPluginPlatform.instance;

  test('$MethodChannelPiperTtsPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPiperTtsPlugin>());
  });

  // Remplacer le test getPlatformVersion par des tests pour les nouvelles méthodes
  test('initialize', () async {
    PiperTtsPlugin piperTtsPlugin = PiperTtsPlugin();
    MockPiperTtsPluginPlatform fakePlatform = MockPiperTtsPluginPlatform();
    PiperTtsPluginPlatform.instance = fakePlatform;

    expect(await piperTtsPlugin.initialize(modelPath: 'model.onnx', configPath: 'model.json'), true);
  });

  test('synthesize', () async {
    PiperTtsPlugin piperTtsPlugin = PiperTtsPlugin();
    MockPiperTtsPluginPlatform fakePlatform = MockPiperTtsPluginPlatform();
    PiperTtsPluginPlatform.instance = fakePlatform;

    final result = await piperTtsPlugin.synthesize(text: 'Bonjour le monde');
    expect(result, isA<Uint8List>());
    expect(result?.isNotEmpty, true);

    final nullResult = await piperTtsPlugin.synthesize(text: '');
    expect(nullResult, isNull);
  });

   test('release', () async {
     PiperTtsPlugin piperTtsPlugin = PiperTtsPlugin();
     MockPiperTtsPluginPlatform fakePlatform = MockPiperTtsPluginPlatform();
     PiperTtsPluginPlatform.instance = fakePlatform;

     // Vérifier qu'aucune exception n'est levée
     await expectLater(piperTtsPlugin.release(), completes);
   });

   // Ajouter des tests pour le Stream si implémenté
}
