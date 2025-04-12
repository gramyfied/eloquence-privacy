import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_stt_plugin/whisper_stt_plugin.dart';
import 'package:whisper_stt_plugin/whisper_stt_plugin_platform_interface.dart';
import 'package:whisper_stt_plugin/whisper_stt_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dart:async'; // Pour Stream
import 'dart:typed_data'; // Pour Uint8List

class MockWhisperSttPluginPlatform
    with MockPlatformInterfaceMixin
    implements WhisperSttPluginPlatform {

  // Mock implementations for the new methods
 @override
 Future<bool> initialize({required String modelName}) async => true; // Simule succès

  @override
  Future<WhisperTranscriptionResult> transcribeChunk({
    required Uint8List audioChunk,
    String? language,
  }) async => WhisperTranscriptionResult(text: 'mock transcription', isPartial: false); // Simule résultat

  @override
  Future<void> release() async {} // Simule void

  // Mock Stream
  final StreamController<WhisperTranscriptionResult> _streamController =
      StreamController.broadcast();

  @override
  Stream<WhisperTranscriptionResult> get transcriptionEvents => _streamController.stream;

  // Helper pour envoyer des événements mockés
  void addMockEvent(WhisperTranscriptionResult event) {
    _streamController.add(event);
  }

  // Helper pour fermer le stream mocké
  void closeMockStream() {
    _streamController.close();
  }
}

void main() {
  final WhisperSttPluginPlatform initialPlatform = WhisperSttPluginPlatform.instance;

  test('$MethodChannelWhisperSttPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWhisperSttPlugin>());
  });

  // Remplacer le test getPlatformVersion par des tests pour les nouvelles méthodes
  test('initialize', () async {
    WhisperSttPlugin whisperSttPlugin = WhisperSttPlugin();
    MockWhisperSttPluginPlatform fakePlatform = MockWhisperSttPluginPlatform();
    WhisperSttPluginPlatform.instance = fakePlatform;

    expect(await whisperSttPlugin.initialize(modelName: 'tiny'), true);
  });

  test('transcribeChunk', () async {
    WhisperSttPlugin whisperSttPlugin = WhisperSttPlugin();
    MockWhisperSttPluginPlatform fakePlatform = MockWhisperSttPluginPlatform();
    WhisperSttPluginPlatform.instance = fakePlatform;

    final result = await whisperSttPlugin.transcribeChunk(audioChunk: Uint8List(0));
    expect(result.text, 'mock transcription');
    expect(result.isPartial, false);
  });

   test('release', () async {
     WhisperSttPlugin whisperSttPlugin = WhisperSttPlugin();
     MockWhisperSttPluginPlatform fakePlatform = MockWhisperSttPluginPlatform();
     WhisperSttPluginPlatform.instance = fakePlatform;

     // Vérifier qu'aucune exception n'est levée
     await expectLater(whisperSttPlugin.release(), completes);
   });

   test('transcriptionEvents stream', () async {
     WhisperSttPlugin whisperSttPlugin = WhisperSttPlugin();
     MockWhisperSttPluginPlatform fakePlatform = MockWhisperSttPluginPlatform();
     WhisperSttPluginPlatform.instance = fakePlatform;

     final event = WhisperTranscriptionResult(text: 'stream event', isPartial: true);

     // S'attendre à recevoir l'événement sur le stream
     expectLater(whisperSttPlugin.transcriptionEvents, emits(event));

     // Envoyer l'événement mocké
     fakePlatform.addMockEvent(event);
     // Fermer le stream pour terminer le test 'emits'
     fakePlatform.closeMockStream();
   });
}
