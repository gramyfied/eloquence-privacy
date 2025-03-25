// Test de base pour l'application Eloquence
import 'package:flutter_test/flutter_test.dart';
import 'package:eloquence_frontend/app/app.dart';

void main() {
  testWidgets('Test de démarrage de l\'application', (WidgetTester tester) async {
    // Construire notre application et déclencher une frame
    await tester.pumpWidget(const EloquenceApp());

    // Vérifier que l'écran de bienvenue s'affiche
    expect(find.text('ELOQUENCE'), findsOneWidget);
    expect(find.text('Votre coach vocal personnel'), findsOneWidget);
    
    // Vérifier que les boutons sont présents
    expect(find.text('CONNEXION'), findsOneWidget);
    expect(find.text('INSCRIPTION'), findsOneWidget);
    expect(find.text('Continuer sans compte'), findsOneWidget);
  });
}
