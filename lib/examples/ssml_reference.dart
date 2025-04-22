/// Référence pour l'utilisation avancée du SSML (Speech Synthesis Markup Language)
/// avec la voix fr-FR-DeniseNeural d'Azure Speech.
///
/// Ce fichier contient des exemples de code SSML pour différentes situations
/// et effets vocaux, afin de maximiser l'expressivité de la synthèse vocale.

/// Utilitaires pour la génération de SSML
class SsmlUtils {
  /// Préfixe SSML standard pour Azure Speech
  static const String _ssmlPrefix = '''
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' 
       xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='fr-FR'>
    <voice name='fr-FR-DeniseNeural'>
''';

  /// Suffixe SSML standard
  static const String _ssmlSuffix = '''
    </voice>
</speak>
''';

  /// Génère un SSML complet à partir du contenu
  static String generateFullSsml(String content) {
    return _ssmlPrefix + content + _ssmlSuffix;
  }
}

/// Exemples de styles d'expression pour fr-FR-DeniseNeural
class ExpressionStyles {
  /// Style amical pour les accueils et introductions
  static String friendly(String text) {
    return '''
<mstts:express-as style="friendly">
    $text
</mstts:express-as>
''';
  }

  /// Style empathique pour les retours et encouragements
  static String empathetic(String text) {
    return '''
<mstts:express-as style="empathetic">
    $text
</mstts:express-as>
''';
  }

  /// Style professionnel pour les simulations d'entretien
  static String professional(String text) {
    return '''
<mstts:express-as style="professional">
    $text
</mstts:express-as>
''';
  }

  /// Combinaison de styles dans un même message
  static String mixed(String friendlyText, String emphaticText, String professionalText) {
    return '''
<mstts:express-as style="friendly">
    $friendlyText
</mstts:express-as>
<break strength="medium" />
<mstts:express-as style="empathetic">
    $emphaticText
</mstts:express-as>
<break strength="medium" />
<mstts:express-as style="professional">
    $professionalText
</mstts:express-as>
''';
  }
}

/// Exemples de contrôle de la prosodie (rythme, hauteur, volume)
class Prosody {
  /// Modification du débit de parole
  static String rate(String text, String rate) {
    // rate peut être: x-slow, slow, medium, fast, x-fast, ou une valeur en pourcentage (e.g., 50%, 150%)
    return '''
<prosody rate="$rate">
    $text
</prosody>
''';
  }

  /// Modification de la hauteur de la voix
  static String pitch(String text, String pitch) {
    // pitch peut être: x-low, low, medium, high, x-high, ou une valeur en pourcentage/Hz/semi-tons
    return '''
<prosody pitch="$pitch">
    $text
</prosody>
''';
  }

  /// Modification du volume
  static String volume(String text, String volume) {
    // volume peut être: silent, x-soft, soft, medium, loud, x-loud, ou une valeur en dB
    return '''
<prosody volume="$volume">
    $text
</prosody>
''';
  }

  /// Combinaison de plusieurs paramètres de prosodie
  static String combined(String text, {String? rate, String? pitch, String? volume}) {
    String attributes = '';
    if (rate != null) attributes += ' rate="$rate"';
    if (pitch != null) attributes += ' pitch="$pitch"';
    if (volume != null) attributes += ' volume="$volume"';
    
    return '''
<prosody$attributes>
    $text
</prosody>
''';
  }
}

/// Exemples d'utilisation des pauses et du timing
class Timing {
  /// Ajout d'une pause
  static String pause(String textBefore, String textAfter, String duration) {
    // duration en millisecondes ou secondes (e.g., "500ms" ou "2s")
    return '''
$textBefore
<break time="$duration" />
$textAfter
''';
  }

  /// Pause avec force spécifiée
  static String pauseWithStrength(String textBefore, String textAfter, String strength) {
    // strength peut être: none, x-weak, weak, medium, strong, x-strong
    return '''
$textBefore
<break strength="$strength" />
$textAfter
''';
  }

  /// Contrôle du débit de parole pour des segments spécifiques
  static String variableRate(List<Map<String, dynamic>> segments) {
    StringBuffer buffer = StringBuffer();
    
    for (var segment in segments) {
      String text = segment['text'];
      String rate = segment['rate'] ?? 'medium';
      
      buffer.write('''
<prosody rate="$rate">
    $text
</prosody>
''');
      
      if (segment != segments.last) {
        buffer.write('<break strength="weak" />');
      }
    }
    
    return buffer.toString();
  }
}

/// Exemples d'utilisation de l'emphase
class Emphasis {
  /// Mise en valeur d'un mot ou d'une phrase
  static String emphasize(String text, String textToEmphasize, String level) {
    // level peut être: strong, moderate, reduced
    final parts = text.split(textToEmphasize);
    if (parts.length != 2) return text; // Si le texte à mettre en valeur n'est pas trouvé
    
    return '''
${parts[0]}<emphasis level="$level">$textToEmphasize</emphasis>${parts[1]}
''';
  }

  /// Mise en valeur de plusieurs segments
  static String multipleEmphasis(String text, List<Map<String, dynamic>> emphasisSegments) {
    String result = text;
    
    // Trier les segments par position décroissante pour éviter de perturber les indices
    emphasisSegments.sort((a, b) => (b['text'] as String).length.compareTo((a['text'] as String).length));
    
    for (var segment in emphasisSegments) {
      String textToEmphasize = segment['text'];
      String level = segment['level'] ?? 'moderate';
      
      result = result.replaceAll(
        textToEmphasize, 
        '<emphasis level="$level">$textToEmphasize</emphasis>'
      );
    }
    
    return result;
  }
}

/// Exemples d'utilisation des balises phonétiques
class Phonetics {
  /// Prononciation phonétique avec l'alphabet phonétique international (IPA)
  static String ipa(String text, String textToReplace, String ipaText) {
    final parts = text.split(textToReplace);
    if (parts.length != 2) return text;
    
    return '''
${parts[0]}<phoneme alphabet="ipa" ph="$ipaText">$textToReplace</phoneme>${parts[1]}
''';
  }

  /// Exemple: correction de la prononciation de mots spécifiques
  static String correctPronunciation(String text) {
    // Exemple pour corriger la prononciation de certains mots techniques ou étrangers
    return text
      .replaceAll('JavaScript', '<phoneme alphabet="ipa" ph="ʒavaˈskript">JavaScript</phoneme>')
      .replaceAll('Python', '<phoneme alphabet="ipa" ph="piˈtɔ̃">Python</phoneme>')
      .replaceAll('React', '<phoneme alphabet="ipa" ph="riˈakt">React</phoneme>');
  }
}

/// Exemples d'utilisation des balises say-as pour des types de contenu spécifiques
class SayAs {
  /// Lecture d'une date
  static String date(String date, String format) {
    // format peut être: mdy, dmy, ymd, ym, my, md, d, m, y
    return '''
<say-as interpret-as="date" format="$format">$date</say-as>
''';
  }

  /// Lecture d'un nombre
  static String number(String number, String format) {
    // format peut être: cardinal, ordinal, digits
    return '''
<say-as interpret-as="$format">$number</say-as>
''';
  }

  /// Lecture d'un numéro de téléphone
  static String telephone(String phoneNumber) {
    return '''
<say-as interpret-as="telephone">$phoneNumber</say-as>
''';
  }

  /// Épellation d'un mot
  static String spell(String text) {
    return '''
<say-as interpret-as="characters">$text</say-as>
''';
  }
}

/// Exemples complets pour différents contextes d'utilisation
class CompleteExamples {
  /// Message d'accueil pour une nouvelle session
  static String welcomeMessage(String userName) {
    return SsmlUtils.generateFullSsml('''
<mstts:express-as style="friendly">
    <prosody rate="95%">
        Bonjour $userName, et bienvenue dans votre session de coaching vocal.
        <break strength="medium" />
        Je suis ravie de vous accompagner aujourd'hui.
        <break strength="medium" />
        Nous allons travailler ensemble pour améliorer votre expression orale.
    </prosody>
</mstts:express-as>
''');
  }

  /// Feedback positif après un exercice
  static String positiveFeedback(String exerciseName, List<String> strengths) {
    StringBuffer strengthsText = StringBuffer();
    
    for (int i = 0; i < strengths.length; i++) {
      strengthsText.write('${i + 1}. ${strengths[i]}');
      if (i < strengths.length - 1) {
        strengthsText.write('<break strength="weak" />');
      }
    }
    
    return SsmlUtils.generateFullSsml('''
<mstts:express-as style="empathetic">
    <prosody rate="90%" pitch="medium">
        Bravo pour votre performance dans l'exercice de $exerciseName !
        <break strength="medium" />
        J'ai particulièrement apprécié :
        <break strength="weak" />
        $strengthsText
        <break strength="medium" />
        <prosody pitch="high">
            Continuez comme ça, vous faites de réels progrès !
        </prosody>
    </prosody>
</mstts:express-as>
''');
  }

  /// Feedback constructif avec suggestions d'amélioration
  static String constructiveFeedback(String exerciseName, List<String> suggestions) {
    StringBuffer suggestionsText = StringBuffer();
    
    for (int i = 0; i < suggestions.length; i++) {
      suggestionsText.write('${i + 1}. ${suggestions[i]}');
      if (i < suggestions.length - 1) {
        suggestionsText.write('<break strength="weak" />');
      }
    }
    
    return SsmlUtils.generateFullSsml('''
<mstts:express-as style="empathetic">
    <prosody rate="85%">
        Merci pour votre participation à l'exercice de $exerciseName.
        <break strength="medium" />
        Voici quelques suggestions pour vous améliorer :
        <break strength="weak" />
        $suggestionsText
        <break strength="medium" />
        <emphasis level="moderate">
            N'oubliez pas que chaque exercice est une opportunité d'apprentissage.
        </emphasis>
        <break strength="weak" />
        Continuez vos efforts, vous progressez à chaque session !
    </prosody>
</mstts:express-as>
''');
  }

  /// Simulation d'entretien professionnel
  static String professionalInterview(String question) {
    return SsmlUtils.generateFullSsml('''
<mstts:express-as style="professional">
    <prosody rate="90%" pitch="medium">
        <break time="500ms" />
        $question
        <break time="500ms" />
    </prosody>
</mstts:express-as>
''');
  }

  /// Instructions pour un exercice de respiration
  static String breathingExercise() {
    return SsmlUtils.generateFullSsml('''
<mstts:express-as style="friendly">
    <prosody rate="80%">
        Nous allons maintenant faire un exercice de respiration.
        <break strength="medium" />
        Inspirez profondément par le nez pendant 4 secondes.
        <break time="1s" />
        <prosody volume="soft" rate="slow">Un... Deux... Trois... Quatre...</prosody>
        <break strength="medium" />
        Retenez votre respiration pendant 2 secondes.
        <break time="1s" />
        <prosody volume="soft" rate="slow">Un... Deux...</prosody>
        <break strength="medium" />
        Expirez lentement par la bouche pendant 6 secondes.
        <break time="1s" />
        <prosody volume="soft" rate="slow">Un... Deux... Trois... Quatre... Cinq... Six...</prosody>
        <break strength="strong" />
        Répétons cet exercice encore deux fois.
    </prosody>
</mstts:express-as>
''');
  }

  /// Présentation d'un nouveau concept ou exercice
  static String introduceExercise(String exerciseName, String description) {
    return SsmlUtils.generateFullSsml('''
<mstts:express-as style="friendly">
    <prosody rate="95%">
        Passons maintenant à l'exercice de <emphasis level="moderate">$exerciseName</emphasis>.
        <break strength="medium" />
        $description
        <break strength="medium" />
        <prosody pitch="high">
            Êtes-vous prêt à commencer ?
        </prosody>
    </prosody>
</mstts:express-as>
''');
  }
}
