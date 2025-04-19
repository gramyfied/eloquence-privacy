import '../tts/ssml_formatter_service.dart';

/// Service pour post-traiter les réponses GPT et améliorer l'utilisation du SSML
class ResponsePostProcessorService {
  /// Améliore une réponse GPT en ajoutant des balises SSML si nécessaire
  static String enhanceWithSsml(String response) {
    // Si la réponse contient déjà du SSML, la retourner telle quelle
    if (SsmlFormatterService.containsSsml(response)) {
      return response;
    }

    // Sinon, ajouter des balises SSML de base pour améliorer la réponse
    return _addBasicSsml(response);
  }

  /// Ajoute des balises SSML de base à une réponse sans SSML
  static String _addBasicSsml(String text) {
    // Diviser le texte en phrases
    final RegExp sentenceBreaks = RegExp(r'(?<=[.!?])\s+');
    final List<String> sentences = text.split(sentenceBreaks);
    
    // Liste des interjections courantes en français
    final List<String> interjections = ['ah', 'oh', 'hmm', 'euh', 'eh bien', 'bon', 'voyons', 'alors'];
    
    // Mots qui méritent souvent une emphase
    final List<String> emphasisWords = ['important', 'crucial', 'essentiel', 'clé', 'fondamental', 'critique', 'vital'];
    
    String result = "";
    
    // Ajouter une interjection au début si le texte ne commence pas par une
    bool startsWithInterjection = false;
    for (String interjection in interjections) {
      if (text.toLowerCase().trim().startsWith(interjection.toLowerCase())) {
        startsWithInterjection = true;
        break;
      }
    }
    
    if (!startsWithInterjection && sentences.length > 1) {
      // Choisir une interjection aléatoire
      final interjection = interjections[DateTime.now().millisecondsSinceEpoch % interjections.length];
      result += "<say-as interpret-as=\"interjection\">$interjection</say-as> <break time=\"200ms\"/> ";
    }
    
    // Traiter chaque phrase
    for (int i = 0; i < sentences.length; i++) {
      String sentence = sentences[i].trim();
      if (sentence.isEmpty) continue;
      
      // Ajouter une variation de débit pour certaines phrases
      if (i % 3 == 0 && sentence.length > 20) {
        // Ralentir légèrement les phrases plus longues
        sentence = "<prosody rate=\"95%\">$sentence</prosody>";
      } else if (i % 4 == 0 && sentence.contains('?')) {
        // Augmenter légèrement le pitch pour les questions
        sentence = "<prosody pitch=\"+5%\">$sentence</prosody>";
      }
      
      // Ajouter de l'emphase sur certains mots importants
      for (String word in emphasisWords) {
        if (sentence.toLowerCase().contains(word.toLowerCase())) {
          // Remplacer le mot par sa version avec emphase
          final RegExp wordRegex = RegExp(word, caseSensitive: false);
          sentence = sentence.replaceAllMapped(wordRegex, (match) {
            return "<emphasis level=\"moderate\">${match.group(0)}</emphasis>";
          });
        }
      }
      
      // Ajouter la phrase au résultat
      result += sentence;
      
      // Ajouter une pause après chaque phrase sauf la dernière
      if (i < sentences.length - 1) {
        // Varier la durée des pauses
        int pauseDuration = 200 + (i % 3) * 50; // 200ms, 250ms ou 300ms
        result += " <break time=\"${pauseDuration}ms\"/> ";
      }
    }
    
    return result;
  }

  /// Vérifie si une réponse contient des erreurs de syntaxe SSML et les corrige
  static String fixSsmlErrors(String response) {
    // Corriger les balises non fermées
    response = _fixUnclosedTags(response);
    
    // Corriger les balises imbriquées incorrectement
    response = _fixNestedTags(response);
    
    return response;
  }

  /// Corrige les balises SSML non fermées
  static String _fixUnclosedTags(String text) {
    // Liste des balises qui nécessitent une fermeture
    final List<String> tagsRequiringClosure = ['prosody', 'emphasis'];
    
    for (String tag in tagsRequiringClosure) {
      // Compter les balises ouvrantes et fermantes
      final RegExp openingTagRegex = RegExp('<$tag[^>]*>');
      final RegExp closingTagRegex = RegExp('</$tag>');
      
      final int openingCount = openingTagRegex.allMatches(text).length;
      final int closingCount = closingTagRegex.allMatches(text).length;
      
      // S'il y a plus de balises ouvrantes que fermantes, ajouter les balises fermantes manquantes
      if (openingCount > closingCount) {
        for (int i = 0; i < openingCount - closingCount; i++) {
          text += "</$tag>";
        }
      }
    }
    
    return text;
  }

  /// Corrige les balises SSML imbriquées incorrectement
  static String _fixNestedTags(String text) {
    // Cette fonction est simplifiée et pourrait être améliorée
    // pour gérer des cas plus complexes d'imbrication incorrecte
    
    // Exemple simple: corriger <prosody><emphasis></prosody></emphasis>
    // en <prosody><emphasis></emphasis></prosody>
    
    // Rechercher les motifs d'imbrication incorrecte
    final RegExp incorrectNestingRegex = RegExp(
      r'<(prosody|emphasis)[^>]*>.*?<(prosody|emphasis)[^>]*>.*?</\1>.*?</\2>',
      dotAll: true
    );
    
    // Si des motifs incorrects sont trouvés, tenter une correction simple
    if (incorrectNestingRegex.hasMatch(text)) {
      // Cette correction est très simplifiée et pourrait ne pas fonctionner dans tous les cas
      text = text.replaceAllMapped(incorrectNestingRegex, (match) {
        final String fullMatch = match.group(0)!;
        final String tag1 = match.group(1)!;
        final String tag2 = match.group(2)!;
        
        // Extraire le contenu entre les balises
        final int openTag1Index = fullMatch.indexOf('<$tag1');
        final int openTag2Index = fullMatch.indexOf('<$tag2', openTag1Index + 1);
        final int closeTag1Index = fullMatch.indexOf('</$tag1>', openTag2Index + 1);
        final int closeTag2Index = fullMatch.indexOf('</$tag2>', closeTag1Index + 1);
        
        if (openTag1Index >= 0 && openTag2Index >= 0 && closeTag1Index >= 0 && closeTag2Index >= 0) {
          final String openTag1 = fullMatch.substring(openTag1Index, fullMatch.indexOf('>', openTag1Index) + 1);
          final String openTag2 = fullMatch.substring(openTag2Index, fullMatch.indexOf('>', openTag2Index) + 1);
          final String content = fullMatch.substring(fullMatch.indexOf('>', openTag2Index) + 1, closeTag1Index);
          
          // Reconstruire avec l'imbrication correcte
          return '$openTag1$openTag2$content</$tag2></$tag1>';
        }
        
        return fullMatch; // Si l'extraction échoue, retourner le texte original
      });
    }
    
    return text;
  }
}
