# Système de Test LiveKit pour Coaching Vocal

Ce système de test permet de vérifier le bon fonctionnement du streaming audio avec LiveKit dans un contexte de coaching vocal interactif avec IA. Il génère des logs détaillés dans le terminal pour identifier les problèmes potentiels dans le pipeline de communication.

## 🎯 Objectifs

- **Tester la robustesse** du streaming audio LiveKit
- **Mesurer les performances** (latence, débit, qualité)
- **Identifier les goulots d'étranglement** dans le pipeline
- **Simuler des conditions réelles** de coaching vocal
- **Générer des rapports détaillés** avec métriques

## 🏗️ Architecture

Le système est composé de plusieurs modules :

```
livekit_test_system/
├── pipeline_logger.py      # Système de logs avancé avec couleurs
├── voice_synthesizer.py    # Générateur de voix synthétisée
├── livekit_client.py       # Client LiveKit pour envoi/réception
├── test_orchestrator.py    # Orchestrateur principal des tests
├── main.py                 # Script principal avec CLI
├── run_tests.py           # Script de lancement rapide
├── config_example.json    # Configuration exemple
├── requirements.txt       # Dépendances Python
└── README.md             # Ce fichier
```

## 🚀 Installation

### 1. Installer les dépendances

```bash
cd livekit_test_system
pip install -r requirements.txt
```

### 2. Configurer LiveKit

Assurez-vous que votre serveur LiveKit est en cours d'exécution :

```bash
# Option 1: Serveur local
livekit-server --dev

# Option 2: Docker
docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit-server --dev
```

### 3. Configuration

Copiez et modifiez le fichier de configuration :

```bash
cp config_example.json config.json
```

Éditez `config.json` avec vos paramètres LiveKit :

```json
{
  "livekit_url": "ws://localhost:7880",
  "api_key": "devkey",
  "api_secret": "secret",
  "room_name": "test_coaching_vocal"
}
```

## 🎮 Utilisation

### Lancement rapide

```bash
python run_tests.py
```

Ce script propose un menu interactif :
- **Test rapide** : Test de base de 20 secondes
- **Suite complète** : Tous les tests avec rapport détaillé

### Utilisation avancée

#### Tous les tests
```bash
python main.py --all
```

#### Test spécifique
```bash
# Test de base (30 secondes par défaut)
python main.py --test basic --duration 60

# Test de stress (50 paquets par défaut)
python main.py --test stress --packets 100 --interval 300

# Test de latence (20 paquets par défaut)
python main.py --test latency --packets 30
```

#### Avec configuration personnalisée
```bash
python main.py --config config.json --all --output results.json
```

#### Variables d'environnement
```bash
export LIVEKIT_URL="ws://your-server:7880"
export LIVEKIT_API_KEY="your-api-key"
export LIVEKIT_API_SECRET="your-secret"
export LIVEKIT_ROOM="test-room"

python main.py --all
```

## 📊 Types de Tests

### 1. Test de Base (`basic`)
- **Durée** : 30 secondes (configurable)
- **Objectif** : Vérifier le fonctionnement normal
- **Phrases** : Salutations et coaching
- **Intervalle** : 2-4 secondes entre les phrases

```bash
python main.py --test basic --duration 45
```

### 2. Test de Stress (`stress`)
- **Paquets** : 50 (configurable)
- **Objectif** : Tester la charge
- **Phrases** : Techniques courtes
- **Intervalle** : 500ms (configurable)

```bash
python main.py --test stress --packets 100 --interval 200
```

### 3. Test de Latence (`latency`)
- **Paquets** : 20 (configurable)
- **Objectif** : Mesurer la réactivité
- **Phrases** : Très courtes
- **Intervalle** : 200ms

```bash
python main.py --test latency --packets 50
```

## 📈 Interprétation des Logs

### Codes Couleur

- 🟢 **Vert** : Succès, informations normales
- 🟡 **Jaune** : Avertissements, latence élevée
- 🔴 **Rouge** : Erreurs, problèmes critiques
- 🔵 **Cyan** : Informations de débogage
- 🟣 **Magenta** : Métriques de performance

### Types de Logs

#### Connexion
```
🔗 CONNECTION | connected: Room: test_coaching_vocal
❌ CONNECTION | failed: Erreur: Connection timeout
```

#### Audio
```
🎵 AUDIO PACKET #1 | Size: 4800 bytes | TS: 1234567890.123
🎧 AUDIO RECEIVED #1 | Size: 4800 bytes | TS: 1234567890.456
```

#### Latence
```
🚀 LATENCY | génération: 45.67 ms
⚡ LATENCY | envoi: 12.34 ms
⏱️ LATENCY | bout_en_bout: 234.56 ms
```

#### Réseau
```
🌐 NETWORK | quality: Excellente qualité détectée
📉 NETWORK | packet_loss: 2.5% de perte détectée
```

### Seuils de Performance

#### Latence
- **🟢 Excellente** : < 100ms
- **🟡 Bonne** : 100-300ms
- **🟠 Acceptable** : 300-500ms
- **🔴 Problématique** : > 500ms

#### Taux de Perte
- **🟢 Excellent** : < 1%
- **🟡 Acceptable** : 1-5%
- **🔴 Problématique** : > 5%

## 📋 Résultats et Rapports

### Métriques Collectées

- **Latence bout-en-bout** (génération → réception)
- **Taux de perte de paquets**
- **Débit** (paquets/seconde)
- **Qualité audio** (analyse des échantillons)
- **Stabilité de connexion**
- **Temps de reconnexion**

### Format de Sortie JSON

```json
{
  "test_name": "basic_test",
  "duration_seconds": 30.5,
  "packets_sent": 12,
  "packets_received": 11,
  "packet_loss_rate": 0.083,
  "latency_stats": {
    "min_ms": 45.2,
    "max_ms": 234.7,
    "avg_ms": 123.4,
    "count": 11
  },
  "errors_count": 1,
  "throughput_pps": 0.39
}
```

## 🔧 Dépannage

### Problèmes Courants

#### 1. Connexion échouée
```
❌ CONNECTION | failed: Erreur: Connection refused
```
**Solutions** :
- Vérifier que LiveKit server est démarré
- Contrôler l'URL (ws:// ou wss://)
- Vérifier les clés API

#### 2. Pas d'audio généré
```
❌ Moteur TTS non disponible
```
**Solutions** :
- Installer pyttsx3 : `pip install pyttsx3`
- Vérifier les pilotes audio système
- Tester avec `espeak` ou `festival`

#### 3. Latence élevée
```
🐌 LATENCY | bout_en_bout: 1234.56 ms
```
**Solutions** :
- Vérifier la charge réseau
- Optimiser la configuration LiveKit
- Réduire la taille des paquets

#### 4. Perte de paquets
```
📉 NETWORK | packet_loss: 15.2% de perte détectée
```
**Solutions** :
- Vérifier la stabilité réseau
- Ajuster les paramètres de reconnexion
- Utiliser un codec plus robuste

### Logs de Débogage

Pour plus de détails, activez le mode verbeux :

```bash
python main.py --test basic --verbose
```

## 🎛️ Configuration Avancée

### Personnalisation des Phrases

Modifiez `voice_synthesizer.py` pour ajouter vos propres phrases :

```python
TEST_PHRASES = {
    'custom': [
        "Votre phrase personnalisée ici",
        "Autre phrase pour vos tests"
    ]
}
```

### Simulation de Conditions Réseau

```python
await client.simulate_network_conditions(
    packet_loss_rate=0.05,  # 5% de perte
    latency_ms=100,         # 100ms de latence
    jitter_ms=20           # Variation de 20ms
)
```

### Configuration TTS

```python
# Dans voice_synthesizer.py
self.engine.setProperty('rate', 120)    # Vitesse
self.engine.setProperty('volume', 0.8)  # Volume
```

## 📚 API Reference

### PipelineLogger

```python
logger = PipelineLogger("COMPONENT_NAME")
logger.info("Message d'information")
logger.latency("operation", 123.45)
logger.audio_packet(packet_id, size, timestamp, metadata)
logger.performance_metric("metric_name", value, "unit")
```

### VoiceSynthesizer

```python
synthesizer = VoiceSynthesizer(temp_dir="./audio")
metadata = await synthesizer.generate_audio("Texte à synthétiser")
async for audio_data in synthesizer.generate_continuous_stream():
    # Traiter l'audio
```

### LiveKitTestClient

```python
client = LiveKitTestClient(url, api_key, api_secret, "sender")
await client.connect("room_name")
await client.send_audio_file(audio_path, metadata)
await client.disconnect()
```

## 🤝 Contribution

Pour contribuer au système de test :

1. **Fork** le repository
2. **Créer** une branche feature
3. **Ajouter** vos améliorations
4. **Tester** avec la suite complète
5. **Soumettre** une pull request

### Ajout de Nouveaux Tests

```python
async def run_custom_test(self, **kwargs) -> Dict[str, Any]:
    """Votre test personnalisé"""
    # Implémentation
    return results
```

## 📄 Licence

Ce système de test est fourni sous licence MIT. Voir le fichier LICENSE pour plus de détails.

## 🆘 Support

Pour obtenir de l'aide :

1. **Consulter** ce README
2. **Vérifier** les logs détaillés
3. **Tester** avec la configuration par défaut
4. **Ouvrir** une issue avec les logs complets

---

**Développé pour le projet Eloquence - Coaching Vocal Interactif avec IA**