# API pour l'exercice "Finales Nettes"

## Vue d'ensemble

L'exercice "Finales Nettes" est conçu pour aider les apprenants à améliorer leur prononciation des finales de mots. Cette documentation explique comment utiliser l'API pour générer des mots avec des finales spécifiques pour cet exercice.

## Endpoint

```
POST /api/ai/coaching/generate-exercise
```

## Authentification

Toutes les requêtes doivent inclure un en-tête d'autorisation avec un jeton Bearer.

```
Authorization: Bearer <votre_token>
```

## Paramètres de la requête

La requête doit être envoyée au format JSON avec les paramètres suivants :

| Paramètre | Type | Description |
|-----------|------|-------------|
| `type` | string | Doit être `"finales_nettes"` pour cet exercice |
| `language` | string | Code de langue (ex: `"fr"`, `"en"`, `"es"`) |
| `params` | object | Paramètres spécifiques à l'exercice |

### Paramètres spécifiques à l'exercice

L'objet `params` peut contenir les propriétés suivantes :

| Propriété | Type | Description | Valeur par défaut |
|-----------|------|-------------|-------------------|
| `level` | string | Niveau de difficulté (`"facile"`, `"moyen"`, `"difficile"`) | `"facile"` |
| `wordCount` | number | Nombre de mots à générer | 6 |
| `targetEndings` | array | Liste des finales de mots à cibler | `["tion", "ment", "ble", "que", "eur", "age"]` |

## Exemple de requête

```json
{
  "type": "finales_nettes",
  "language": "fr",
  "params": {
    "level": "facile",
    "wordCount": 6,
    "targetEndings": ["tion", "ment", "ble", "que", "eur", "age"]
  }
}
```

## Exemple de réponse

```json
{
  "success": true,
  "data": {
    "words": [
      {
        "word": "relation",
        "targetEnding": "tion"
      },
      {
        "word": "changement",
        "targetEnding": "ment"
      },
      {
        "word": "meuble",
        "targetEnding": "ble"
      },
      {
        "word": "physique",
        "targetEnding": "que"
      },
      {
        "word": "chaleur",
        "targetEnding": "eur"
      },
      {
        "word": "image",
        "targetEnding": "age"
      }
    ]
  }
}
```

## Finales disponibles par langue

### Français (fr)

- `"tion"` : action, attention, solution, etc.
- `"ment"` : simplement, moment, rapidement, etc.
- `"ble"` : table, possible, ensemble, etc.
- `"que"` : politique, musique, pratique, etc.
- `"eur"` : bonheur, couleur, fleur, etc.
- `"age"` : voyage, message, visage, etc.

### Anglais (en)

- `"tion"` : action, attention, solution, etc.
- `"ment"` : moment, movement, statement, etc.
- `"ble"` : table, possible, responsible, etc.
- `"que"` : technique, unique, antique, etc.
- `"er"` : teacher, player, water, etc.
- `"age"` : message, language, image, etc.

### Espagnol (es)

- `"ción"` : acción, atención, solución, etc.
- `"mento"` : momento, movimiento, sentimiento, etc.
- `"ble"` : posible, amable, notable, etc.
- `"dad"` : ciudad, verdad, realidad, etc.
- `"dor"` : jugador, trabajador, profesor, etc.
- `"aje"` : viaje, mensaje, lenguaje, etc.

## Niveaux de difficulté

L'API propose trois niveaux de difficulté pour les mots :

- `"facile"` : Mots courts et courants, adaptés aux débutants.
- `"moyen"` : Mots de longueur moyenne, adaptés aux apprenants intermédiaires.
- `"difficile"` : Mots longs et moins courants, adaptés aux apprenants avancés.

## Gestion des erreurs

En cas d'erreur, l'API renvoie une réponse avec un code d'état HTTP approprié et un message d'erreur au format JSON.

Exemple de réponse d'erreur :

```json
{
  "success": false,
  "error": {
    "message": "Type d'exercice non supporté: invalid_type",
    "statusCode": 400
  }
}
```

## Implémentation côté client

Voici un exemple d'implémentation en Dart pour appeler cette API depuis une application Flutter :

```dart
Future<List<WordTarget>> fetchFinalesNettesWords({
  required String language,
  String level = 'facile',
  int wordCount = 6,
  List<String>? targetEndings,
}) async {
  final url = Uri.parse('$BASE_URL/api/ai/coaching/generate-exercise');
  
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $API_KEY',
    },
    body: json.encode({
      'type': 'finales_nettes',
      'language': language,
      'params': {
        'level': level,
        'wordCount': wordCount,
        'targetEndings': targetEndings ?? ['tion', 'ment', 'ble', 'que', 'eur', 'age'],
      },
    }),
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['success'] == true && data['data'] != null && data['data']['words'] != null) {
      final List<dynamic> wordsData = data['data']['words'];
      return wordsData.map((wordData) => WordTarget(
        word: wordData['word'],
        targetEnding: wordData['targetEnding'],
      )).toList();
    } else {
      throw Exception('Format de réponse invalide');
    }
  } else {
    throw Exception('Échec de la récupération des mots: ${response.statusCode}');
  }
}

class WordTarget {
  final String word;
  final String targetEnding;
  
  WordTarget({required this.word, required this.targetEnding});
}
```

## Notes techniques

- L'API utilise un fichier de mots prédéfinis pour chaque langue et niveau de difficulté.
- Si Ollama n'est pas disponible, l'API utilise les mots prédéfinis.
- Si une finale demandée n'est pas disponible dans les mots prédéfinis, l'API essaiera de générer un mot avec cette finale en utilisant le LLM.
