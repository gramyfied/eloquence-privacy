import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:eloquence_flutter/services/interactive_exercise/realtime_audio_pipeline.dart';
import 'package:eloquence_flutter/services/audio/audio_service.dart';
import 'package:eloquence_flutter/services/azure/azure_speech_service.dart';
import 'package:eloquence_flutter/services/azure/azure_tts_service.dart';

// Générer les mocks
@GenerateMocks([AudioService, AzureSpeechService, AzureTtsService])
import 'realtime_audio_pipeline_test.mocks.dart';

void main() {
  late MockAudioService mockAudioService;
  late MockAzureSpeechService mockAzureSpeechService;
  late MockAzureTtsService mockAzureTtsService;
  late RealTimeAudioPipeline pipeline;

  setUp(() {
    mockAudioService = MockAudioService();
    mockAzureSpeechService = MockAzureSpeechService();
    mockAzureTtsService = MockAzureTtsService();
    
    // Configurer les mocks
    when(mockAzureSpeechService.recognitionStream).thenAnswer((_) => const Stream.empty());
    
    pipeline = RealTimeAudioPipeline(
      mockAudioService,
      mockAzureSpeechService,
      mockAzureTtsService,
    );
  });

  test('dispose should prevent further operations on ValueNotifiers', () async {
    // Disposer le pipeline
    pipeline.dispose();
    
    // Vérifier que stop() ne lance pas d'exception après dispose
    await pipeline.stop();
    
    // Vérifier que start() ne lance pas d'exception après dispose
    await pipeline.start('fr-FR');
    
    // Vérifier que speakText() ne lance pas d'exception après dispose
    await pipeline.speakText('Test');
  });
}
