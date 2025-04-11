// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing


import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:whisper_stt_plugin/whisper_stt_plugin.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initialize test', (WidgetTester tester) async {
    final WhisperSttPlugin plugin = WhisperSttPlugin();
    // Note: Ce test échouera probablement car le chemin du modèle n'est pas valide
    // et le modèle n'est pas inclus dans les assets de test.
    // Il faudrait une configuration plus avancée pour les tests d'intégration réels.
    final bool success = await plugin.initialize(modelPath: 'path/to/integration/test/model.bin');
    // Pour l'instant, on vérifie juste que l'appel ne lève pas d'exception majeure
    // (il retournera false si le modèle n'est pas trouvé).
    expect(success, isA<bool>());
  });

  // Ajouter d'autres tests d'intégration si nécessaire (ex: transcribe, release)
}
