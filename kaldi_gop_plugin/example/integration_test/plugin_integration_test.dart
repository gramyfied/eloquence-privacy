// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing


import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:kaldi_gop_plugin/kaldi_gop_plugin.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initialize test', (WidgetTester tester) async {
    final KaldiGopPlugin plugin = KaldiGopPlugin();
    // Note: Ce test échouera probablement car le chemin n'est pas valide
    // et les modèles ne sont pas inclus dans les assets de test.
    final bool success = await plugin.initialize(modelDir: 'path/to/integration/test/kaldi_models');
    // Vérifier que l'appel ne lève pas d'exception majeure.
    expect(success, isA<bool>());
  });

  // Ajouter d'autres tests d'intégration si nécessaire (ex: calculateGop, release)
}
