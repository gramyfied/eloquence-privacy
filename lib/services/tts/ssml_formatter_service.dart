/// Service pour formater le texte avec des balises SSML (Speech Synthesis Markup Language)
/// Ce service aide à enrichir la synthèse vocale avec des variations de ton, de rythme et d'intonation.
class SsmlFormatterService {
  /// Ajoute une pause dans le texte
  /// [duration] est en millisecondes
  static String addPause(String text, int duration) {
    return "<break time=\"${duration}ms\"/>";
  }

  /// Modifie le débit de parole
  /// [rate] est un pourcentage (100% = normal, <100% = plus lent, >100% = plus rapide)
  static String setRate(String text, int rate) {
    return "<prosody rate=\"$rate%\">$text</prosody>";
  }

  /// Modifie la hauteur de la voix
  /// [pitch] est un pourcentage ou une valeur relative (+10%, -5%, etc.)
  static String setPitch(String text, String pitch) {
    return "<prosody pitch=\"$pitch\">$text</prosody>";
  }

  /// Ajoute de l'emphase sur un mot ou une phrase
  /// [level] peut être "strong", "moderate", "reduced"
  static String addEmphasis(String text, String level) {
    return "<emphasis level=\"$level\">$text</emphasis>";
  }

  /// Ajoute une interjection
  /// [interjection] est l'interjection à prononcer (wow, hmm, etc.)
  static String addInterjection(String interjection) {
    return "<say-as interpret-as=\"interjection\">$interjection</say-as>";
  }

  /// Détecte si le texte contient des balises SSML
  static bool containsSsml(String text) {
    return text.contains("<break") || 
           text.contains("<prosody") || 
           text.contains("<emphasis") || 
           text.contains("<say-as");
  }

  /// Divise un texte long en segments SSML pour une meilleure gestion
  /// Utile pour les textes longs qui pourraient dépasser les limites de taille des services TTS
  static List<String> splitTextIntoSsmlSegments(String text, {int maxLength = 1000}) {
    // Si le texte ne contient pas de SSML, le diviser simplement par taille
    if (!containsSsml(text)) {
      return _splitPlainText(text, maxLength);
    }

    // Pour le texte avec SSML, une approche plus sophistiquée est nécessaire
    // Cette implémentation est simplifiée et pourrait être améliorée
    List<String> segments = [];
    
    // Diviser aux pauses naturelles (points, points-virgules, etc.)
    final RegExp sentenceBreaks = RegExp(r'(?<=[.!?;])\s+');
    final List<String> sentences = text.split(sentenceBreaks);
    
    String currentSegment = "";
    
    for (String sentence in sentences) {
      // Si ajouter cette phrase dépasse la limite, commencer un nouveau segment
      if (currentSegment.length + sentence.length > maxLength && currentSegment.isNotEmpty) {
        segments.add(currentSegment);
        currentSegment = sentence;
      } else {
        // Sinon, ajouter à la phrase courante
        if (currentSegment.isNotEmpty) {
          currentSegment += " ";
        }
        currentSegment += sentence;
      }
    }
    
    // Ajouter le dernier segment s'il n'est pas vide
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }
    
    return segments;
  }

  /// Divise un texte simple en segments de taille maximale
  static List<String> _splitPlainText(String text, int maxLength) {
    List<String> segments = [];
    
    for (int i = 0; i < text.length; i += maxLength) {
      int end = (i + maxLength < text.length) ? i + maxLength : text.length;
      
      // Essayer de terminer le segment à un espace pour éviter de couper les mots
      if (end < text.length) {
        int lastSpace = text.substring(i, end).lastIndexOf(' ');
        if (lastSpace != -1) {
          end = i + lastSpace + 1; // +1 pour inclure l'espace
        }
      }
      
      segments.add(text.substring(i, end));
    }
    
    return segments;
  }

  /// Enveloppe le texte dans un format SSML complet pour Azure TTS
  static String wrapInSsmlFormat(String text, String voiceName, {String language = 'fr-FR'}) {
    return '''
    <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='$language'>
        <voice name='$voiceName'>
            $text
        </voice>
    </speak>
    ''';
  }
}
