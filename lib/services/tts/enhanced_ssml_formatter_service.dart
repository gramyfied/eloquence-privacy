import 'package:flutter/foundation.dart';
import 'emotion_analyzer_service.dart';

/// Service amélioré pour formater le texte avec des balises SSML avancées
/// Étend les fonctionnalités du SsmlFormatterService standard avec des
/// capacités d'expression émotionnelle et de formatage complexe.
class EnhancedSsmlFormatterService {
  // Styles émotionnels disponibles pour Azure TTS
  static final Map<String, String> emotionalStyles = {
    'neutral': '',
    'cheerful': '<mstts:express-as style="cheerful">',
    'empathetic': '<mstts:express-as style="empathetic">',
    'excited': '<mstts:express-as style="excited" styledegree="2">',
    'friendly': '<mstts:express-as style="friendly">',
    'terrified': '<mstts:express-as style="terrified">',
    'shouting': '<mstts:express-as style="shouting">',
    'unfriendly': '<mstts:express-as style="unfriendly">',
    'whispering': '<mstts:express-as style="whispering">',
    'hopeful': '<mstts:express-as style="hopeful">',
    'sad': '<mstts:express-as style="sad">',
    'angry': '<mstts:express-as style="angry">',
  };
  
  /// Construire un SSML avec émotion et formatage avancé
  static String buildEmotionalSSML({
    required String text,
    required String voice,
    String emotion = 'neutral',
    double rate = 1.0,
    double pitch = 0.0,
    List<EmphasisPoint>? emphasisPoints,
    List<PausePoint>? pausePoints,
    String language = 'fr-FR',
  }) {
    final buffer = StringBuffer();
    
    // Début du document SSML
    buffer.write('<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" ');
    buffer.write('xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="$language">');
    buffer.write('<voice name="$voice">');
    
    // Ajouter le style émotionnel si spécifié
    if (emotion != 'neutral' && emotionalStyles.containsKey(emotion)) {
      buffer.write(emotionalStyles[emotion]);
    }
    
    // Ajouter les paramètres de prosodie globaux
    buffer.write('<prosody rate="${rate.toStringAsFixed(1)}" ');
    buffer.write('pitch="${pitch >= 0 ? '+' : ''}${pitch.toStringAsFixed(1)}st">');
    
    // Traiter le texte avec emphases et pauses
    if (emphasisPoints != null || pausePoints != null) {
      _processTextWithMarkup(buffer, text, emphasisPoints, pausePoints);
    } else {
      buffer.write(_escapeXml(text));
    }
    
    // Fermer les balises
    buffer.write('</prosody>');
    if (emotion != 'neutral' && emotionalStyles.containsKey(emotion)) {
      buffer.write('</mstts:express-as>');
    }
    buffer.write('</voice></speak>');
    
    final result = buffer.toString();
    
    if (kDebugMode) {
      print("EnhancedSSML: Generated SSML with emotion '$emotion':");
      print(result);
    }
    
    return result;
  }
  
  /// Traiter le texte avec des points d'emphase et de pause
  static void _processTextWithMarkup(
    StringBuffer buffer,
    String text,
    List<EmphasisPoint>? emphasisPoints,
    List<PausePoint>? pausePoints,
  ) {
    // Si aucun point de markup, simplement échapper le texte
    if ((emphasisPoints == null || emphasisPoints.isEmpty) && 
        (pausePoints == null || pausePoints.isEmpty)) {
      buffer.write(_escapeXml(text));
      return;
    }
    
    // Créer une liste combinée de tous les points de markup
    final allPoints = <MarkupPoint>[];
    
    if (emphasisPoints != null) {
      for (final point in emphasisPoints) {
        allPoints.add(MarkupPoint(
          index: point.startIndex,
          isStart: true,
          markup: '<emphasis level="${point.level}">',
          priority: 1,
        ));
        
        allPoints.add(MarkupPoint(
          index: point.endIndex,
          isStart: false,
          markup: '</emphasis>',
          priority: 1,
        ));
      }
    }
    
    if (pausePoints != null) {
      for (final point in pausePoints) {
        allPoints.add(MarkupPoint(
          index: point.index,
          isStart: true,
          markup: '<break time="${point.durationMs}ms"/>',
          priority: 2,
        ));
      }
    }
    
    // Trier les points par index et priorité
    allPoints.sort((a, b) {
      final indexCompare = a.index.compareTo(b.index);
      if (indexCompare != 0) return indexCompare;
      
      // Pour le même index, les balises de fermeture viennent avant les balises d'ouverture
      if (!a.isStart && b.isStart) return -1;
      if (a.isStart && !b.isStart) return 1;
      
      // Pour le même type de balise, trier par priorité
      return b.priority.compareTo(a.priority);
    });
    
    // Construire le texte avec les balises
    int lastIndex = 0;
    
    for (final point in allPoints) {
      if (point.index > lastIndex && point.index <= text.length) {
        buffer.write(_escapeXml(text.substring(lastIndex, point.index)));
      }
      
      buffer.write(point.markup);
      
      if (!point.isStart) {
        lastIndex = point.index;
      }
    }
    
    // Ajouter le reste du texte
    if (lastIndex < text.length) {
      buffer.write(_escapeXml(text.substring(lastIndex)));
    }
  }
  
  /// Échapper les caractères XML
  static String _escapeXml(String text) {
    return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
  }
  
  /// Ajoute une interjection au début du texte si nécessaire
  static String addIntroductoryInterjection(String text) {
    // Liste des interjections courantes en français
    final interjections = ['ah', 'oh', 'hmm', 'euh', 'eh bien', 'bon', 'voyons', 'alors'];
    
    // Vérifier si le texte commence déjà par une interjection
    for (final interjection in interjections) {
      if (text.toLowerCase().trim().startsWith(interjection.toLowerCase())) {
        return text; // Le texte commence déjà par une interjection
      }
    }
    
    // Choisir une interjection aléatoire
    final interjection = interjections[DateTime.now().millisecondsSinceEpoch % interjections.length];
    return "<say-as interpret-as=\"interjection\">$interjection</say-as> <break time=\"200ms\"/> $text";
  }
  
  /// Améliore un texte simple avec des balises SSML de base
  static String enhanceWithBasicSsml(String text) {
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
  
  /// Vérifie si un texte contient déjà des balises SSML
  static bool containsSsml(String text) {
    return text.contains("<break") || 
           text.contains("<prosody") || 
           text.contains("<emphasis") || 
           text.contains("<say-as") ||
           text.contains("<mstts:express-as");
  }
  
  /// Corrige les erreurs de syntaxe SSML courantes
  static String fixSsmlErrors(String ssml) {
    // Corriger les balises non fermées
    ssml = _fixUnclosedTags(ssml);
    
    // Corriger les balises imbriquées incorrectement
    ssml = _fixNestedTags(ssml);
    
    return ssml;
  }
  
  /// Corrige les balises SSML non fermées
  static String _fixUnclosedTags(String text) {
    // Liste des balises qui nécessitent une fermeture
    final List<String> tagsRequiringClosure = ['prosody', 'emphasis', 'voice', 'mstts:express-as'];
    
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
      r'<(prosody|emphasis|voice|mstts:express-as)[^>]*>.*?<(prosody|emphasis|voice|mstts:express-as)[^>]*>.*?</\1>.*?</\2>',
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

/// Classe pour représenter un point de markup dans le texte
class MarkupPoint {
  final int index;
  final bool isStart;
  final String markup;
  final int priority;
  
  MarkupPoint({
    required this.index,
    required this.isStart,
    required this.markup,
    required this.priority,
  });
}
