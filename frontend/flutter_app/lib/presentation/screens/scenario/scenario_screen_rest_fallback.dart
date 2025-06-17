import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Utilisation de Riverpod
import '../../providers/livekit_audio_provider_rest_fallback.dart';
import '../../providers/scenario_provider.dart'; // Contient scenariosProvider et sessionProvider
import '../../../data/models/session_model.dart';

class ScenarioScreenRestFallback extends ConsumerStatefulWidget { // Changement en ConsumerStatefulWidget
  @override
  _ScenarioScreenRestFallbackState createState() => _ScenarioScreenRestFallbackState();
}

class _ScenarioScreenRestFallbackState extends ConsumerState<ScenarioScreenRestFallback> { // Changement en ConsumerState
  // _audioProvider sera initialisé via ref.watch ou ref.read
  bool _isStreamingActive = false;
  // Garder une référence au listener pour le supprimer dans dispose
  RemoveListener? _sessionListenerUnsubscriber;


  @override
  void initState() {
    super.initState();
    
    // Écouter les changements de session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // addListener pour StateNotifier de Riverpod
      // La méthode addListener retourne une fonction pour se désabonner
      _sessionListenerUnsubscriber = ref.read(sessionProvider.notifier).addListener((state) { // Signature correcte pour StateNotifier
        _onSessionChanged(state.value); // Passer la valeur de l'état
      });
    });
  }

  void _onSessionChanged(SessionModel? session) { // Prend SessionModel? en argument
    final audioProvider = ref.read(liveKitConversationProviderRestFallback); // Lire le ChangeNotifier via Riverpod
    if (session != null && !audioProvider.isConnected) {
      print('[REST_FALLBACK_SCREEN] Nouvelle session détectée: ${session.sessionId}');
      _connectToSession(session);
    }
  }

  Future<void> _connectToSession(SessionModel session) async {
    print('[REST_FALLBACK_SCREEN] Connexion à la session REST: ${session.sessionId}');
    final audioProvider = ref.read(liveKitConversationProviderRestFallback); // Lire le ChangeNotifier via Riverpod
    
    final success = await audioProvider.connectWithSession(session);
    
    if (success) {
      print('[REST_FALLBACK_SCREEN] ✅ Connexion REST réussie');
      if (mounted) { // Vérifier si le widget est toujours monté
        setState(() {
          _isStreamingActive = true;
        });
      }
      await audioProvider.startRecording();
    } else {
      print('[REST_FALLBACK_SCREEN] ❌ Échec connexion REST');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utilisation de ref.watch pour écouter les changements des providers Riverpod
    final scenariosAsyncValue = ref.watch(scenariosProvider); // FutureProvider
    final sessionAsyncValue = ref.watch(sessionProvider); // StateNotifierProvider
    final liveKitConversationState = ref.watch(liveKitConversationProviderRestFallback); // ChangeNotifierProvider

    return Scaffold(
      appBar: AppBar(
        title: Text('Eloquence 2.0 - REST Fallback'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de diagnostic
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 Solution REST Fallback Active',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('✅ Contourne le problème WebRTC'),
                  Text('✅ Utilise l\'API REST pour l\'audio'),
                  Text('✅ Compatible tous réseaux'),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // État de la connexion
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: liveKitConversationState.isConnected ? Colors.green.shade50 : Colors.orange.shade50,
                border: Border.all(
                  color: liveKitConversationState.isConnected ? Colors.green : Colors.orange,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'État de la Connexion REST',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Connecté: ${liveKitConversationState.isConnected ? "✅ Oui" : "❌ Non"}'),
                  Text('En cours: ${liveKitConversationState.isConnecting ? "🔄 Oui" : "⏸️ Non"}'),
                  Text('Enregistrement: ${liveKitConversationState.isRecording ? "🎙️ Actif" : "⏹️ Arrêté"}'),
                  if (liveKitConversationState.error != null)
                    Text(
                      'Erreur: ${liveKitConversationState.error}',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Session actuelle
            sessionAsyncValue.when(
              data: (session) {
                if (session != null) {
                  return Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Active',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text('ID: ${session.sessionId}'),
                        Text('Room: ${session.roomName}'),
                        if (session.initialMessage != null && session.initialMessage!['text'] != null) // Vérification de nullité
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Message initial: ${session.initialMessage!['text']}', // Accès sécurisé
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  );
                }
                return Container(); // Retourne un widget vide si pas de session
              },
              loading: () => CircularProgressIndicator(),
              error: (err, stack) => Text('Erreur de session: $err'),
            ),
            
            SizedBox(height: 20),
            
            // Boutons de contrôle
            Row(
              children: [
                ElevatedButton(
                  onPressed: liveKitConversationState.isConnected && !liveKitConversationState.isRecording
                      ? () => ref.read(liveKitConversationProviderRestFallback).startRecording()
                      : null,
                  child: Text('🎙️ Démarrer'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: liveKitConversationState.isRecording
                      ? () => ref.read(liveKitConversationProviderRestFallback).stopRecording()
                      : null,
                  child: Text('⏹️ Arrêter'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => ref.read(liveKitConversationProviderRestFallback).disconnect(),
                  child: Text('🔌 Déconnecter'),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Bouton pour sélectionner un scénario
            ElevatedButton(
              onPressed: () => _showScenarioModal(context),
              child: Text('📋 Sélectionner un Scénario'),
            ),
          ],
        ),
      ),
    );
  }

  void _showScenarioModal(BuildContext context) {
    final scenariosAsyncValue = ref.watch(scenariosProvider); // Utilisation de ref.watch
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choisir un Scénario',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            scenariosAsyncValue.when(
              data: (scenarios) {
                if (scenarios.isEmpty) {
                  return Text('Aucun scénario disponible');
                }
                return Column(
                  children: scenarios.map((scenario) => ListTile(
                    title: Text(scenario.name), 
                    subtitle: Text(scenario.description),
                    onTap: () {
                      Navigator.pop(context);
                      _startSession(scenario.id);
                    },
                  )).toList(),
                );
              },
              loading: () => CircularProgressIndicator(),
              error: (err, stack) => Text('Erreur de chargement des scénarios: $err'),
            ),
          ],
        ),
      ),
    );
  }

  void _startSession(String scenarioId) async {
    final sessionNotifier = ref.read(sessionProvider.notifier); // Accès au notifier Riverpod
    await sessionNotifier.startSession(scenarioId);
  }

  @override
  void dispose() {
    // Se désabonner du listener
    _sessionListenerUnsubscriber?.call();
    // Le ChangeNotifier est géré par Riverpod, pas besoin de le disposer manuellement ici.
    // ref.read(liveKitConversationProviderRestFallback).dispose(); // Ne pas faire ça si géré par Riverpod
    super.dispose();
  }
}