import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart'; // Utilisation du logger existant

class SyllabificationService {
  final Logger _logger = Logger(); // Initialisation du logger
  Map<String, String> _lexicon = {};
  bool _isLoaded = false;

  // Méthode pour charger le lexique depuis les assets JSON
  Future<void> loadLexicon() async {
    if (_isLoaded) {
      _logger.i('Syllabification lexicon already loaded.');
      return;
    }
    try {
      _logger.i('Loading syllabification lexicon...');
      final String jsonString = await rootBundle.loadString('assets/lexique/lexique_syllabes.json');
      // Décoder le JSON en Map<String, dynamic> puis caster en Map<String, String>
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _lexicon = jsonMap.map((key, value) => MapEntry(key, value.toString()));
      _isLoaded = true;
      _logger.i('Syllabification lexicon loaded successfully with ${_lexicon.length} entries.');
    } catch (e) {
      _logger.e('Failed to load syllabification lexicon: $e');
      // Gérer l'erreur comme nécessaire (par exemple, lancer une exception, utiliser des valeurs par défaut, etc.)
      _isLoaded = false; // Marquer comme non chargé en cas d'erreur
    }
  }

  // Méthode pour obtenir la syllabification d'un mot
  // Retourne la syllabification si trouvée, sinon null
  String? getSyllabification(String word) {
    if (!_isLoaded) {
      _logger.w('Syllabification lexicon is not loaded. Call loadLexicon() first.');
      // Optionnel : tenter de charger ici si ce n'est pas fait ? Ou juste retourner null.
      // await loadLexicon(); // Décommenter pour chargement paresseux (attention à l'async)
      // if (!_isLoaded) return null; // Vérifier à nouveau après tentative de chargement
      return null;
    }
    
    // Normaliser le mot (ex: minuscule) pour correspondre aux clés du JSON si nécessaire
    // Ici, on suppose que les clés sont déjà dans le format attendu.
    // Si le lexique contient des majuscules/minuscules mixtes, ajustez la recherche.
    final String normalizedWord = word.toLowerCase(); // Exemple de normalisation

    final String? syllabification = _lexicon[normalizedWord];

    if (syllabification == null) {
      _logger.d('Syllabification not found for word: $word (normalized: $normalizedWord)');
    }

    return syllabification;
  }

  // Méthode pour vérifier si le lexique est chargé
  bool get isLoaded => _isLoaded;
}
