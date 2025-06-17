import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

// Note: Il faudra potentiellement ajouter des imports pour le logging ou d'autres utilitaires
// et s'assurer que les dépendances (comme livekit_client) sont bien dans pubspec.yaml

/// Modèle pour les données audio brutes.
class AudioData {
  final Uint8List rawData;
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final double rmsLevel;
  final DateTime timestamp;

  AudioData({
    required this.rawData,
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.rmsLevel,
    required this.timestamp,
  });

  /// Propriété calculée pour obtenir les samples PCM16 si applicable.
  /// Ceci est une simplification ; une conversion plus robuste pourrait être nécessaire
  /// en fonction du format exact des données brutes.
  List<int> get pcm16Samples {
    if (bitsPerSample == 16 && rawData.isNotEmpty) {
      // Supposons que rawData est déjà en PCM16 Little Endian
      final samples = <int>[];
      for (var i = 0; i < rawData.lengthInBytes; i += 2) {
        samples.add(rawData.buffer.asByteData().getInt16(i, Endian.little));
      }
      return samples;
    }
    return [];
  }
}

/// Classe principale pour gérer l'extraction des données audio brutes.
class AudioDataExtractor {
  static const String _tag = 'AudioDataExtractor';
  static const MethodChannel _channel = MethodChannel('com.example.eloquence/audio_data');

  final StreamController<AudioData> _audioDataController = StreamController<AudioData>.broadcast();
  Stream<AudioData> get audioDataStream => _audioDataController.stream;

  RemoteAudioTrack? _currentTrack;
  String? _currentTrackSid;

  AudioDataExtractor() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    // print('$_tag: Appel de méthode reçu depuis natif: ${call.method}');
    switch (call.method) {
      case 'onAudioDataReceived':
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null) {
          try {
            final rawData = args['rawData'] as Uint8List;
            final sampleRate = args['sampleRate'] as int;
            final channels = args['channels'] as int;
            final bitsPerSample = args['bitsPerSample'] as int;
            final rmsLevel = (args['rmsLevel'] as num?)?.toDouble() ?? 0.0; // Gérer null et convertir

            // print('$_tag: Données audio reçues - ${rawData.length} bytes, SR: $sampleRate, RMS: $rmsLevel');

            _audioDataController.add(AudioData(
              rawData: rawData,
              sampleRate: sampleRate,
              channels: channels,
              bitsPerSample: bitsPerSample,
              rmsLevel: rmsLevel,
              timestamp: DateTime.now(), // Utiliser l'heure de réception côté Dart
            ));
          } catch (e) {
            // print('$_tag: Erreur lors du parsing des données audio: $e');
            // Gérer l'erreur, peut-être via un stream d'erreurs séparé
          }
        }
        break;
      default:
        // print('$_tag: Méthode non gérée: ${call.method}');
    }
  }

  /// Démarre l'extraction pour une track audio distante.
  Future<void> startExtraction(RemoteAudioTrack track) async {
    if (_currentTrackSid == track.sid) {
      // print('$_tag: Extraction déjà en cours pour la track ${track.sid}');
      return;
    }
    if (_currentTrackSid != null) {
      await stopExtraction(); // Arrêter l'extraction précédente si elle existe
    }

    _currentTrack = track;
    _currentTrackSid = track.sid;

    // print('$_tag: Démarrage de l'extraction pour la track ${track.sid}');
    try {
      await _channel.invokeMethod('startExtraction', {'trackSid': track.sid});
      // print('$_tag: Méthode startExtraction invoquée pour ${track.sid}');
    } on PlatformException catch (e) {
      // print('$_tag: Erreur PlatformException lors de startExtraction: ${e.message}');
      // Gérer l'erreur, notifier l'UI, etc.
      _currentTrack = null;
      _currentTrackSid = null;
      rethrow;
    } catch (e) {
      // print('$_tag: Erreur inconnue lors de startExtraction: $e');
      _currentTrack = null;
      _currentTrackSid = null;
      rethrow;
    }
  }

  /// Arrête l'extraction audio.
  Future<void> stopExtraction() async {
    if (_currentTrackSid == null) {
      // print('$_tag: Aucune extraction en cours à arrêter.');
      return;
    }
    // print('$_tag: Arrêt de l'extraction pour la track $_currentTrackSid');
    try {
      await _channel.invokeMethod('stopExtraction', {'trackSid': _currentTrackSid});
      // print('$_tag: Méthode stopExtraction invoquée pour $_currentTrackSid');
    } on PlatformException catch (e) {
      // print('$_tag: Erreur PlatformException lors de stopExtraction: ${e.message}');
      // Gérer l'erreur
    } catch (e) {
      // print('$_tag: Erreur inconnue lors de stopExtraction: $e');
    } finally {
      _currentTrack = null;
      _currentTrackSid = null;
    }
  }

  void dispose() {
    // print('$_tag: Dispose appelé');
    stopExtraction();
    _audioDataController.close();
  }
}

/// Wrapper pour RemoteAudioTrack afin de faciliter l'utilisation avec AudioDataExtractor.
class EnhancedRemoteAudioTrack {
  final RemoteAudioTrack track;
  final String participantIdentity; // Ajout de l'identité du participant
  final AudioDataExtractor _extractor;
  StreamSubscription? _subscription;

  Stream<AudioData> get audioDataStream => _extractor.audioDataStream;

  EnhancedRemoteAudioTrack(this.track, this.participantIdentity) : _extractor = AudioDataExtractor();

  Future<void> startListening() async {
    await _extractor.startExtraction(track);
  }

  Future<void> stopListening() async {
    await _extractor.stopExtraction();
  }

  void dispose() {
    _subscription?.cancel();
    _extractor.dispose();
  }
}

/// Service pour gérer les données audio de toutes les tracks d'une room.
class RoomAudioDataService {
  final Room room;
  final Map<String, EnhancedRemoteAudioTrack> _trackExtractors = {};
  final StreamController<Map<String, AudioData>> _mixedAudioController = StreamController<Map<String, AudioData>>.broadcast();
  final Map<String, StreamSubscription> _participantSubscriptions = {};

  Stream<Map<String, AudioData>> get mixedAudioStream => _mixedAudioController.stream;

  RoomAudioDataService(this.room) {
    _setupListeners();
    _processExistingTracks();
  }

  void _setupListeners() {
    room.events.listen((event) {
      if (event is TrackSubscribedEvent) {
        if (event.track is RemoteAudioTrack && event.participant is RemoteParticipant) {
          _addParticipantTrack(event.participant as RemoteParticipant, event.track as RemoteAudioTrack);
        }
      } else if (event is TrackUnsubscribedEvent) {
         if (event.track is RemoteAudioTrack && event.participant is RemoteParticipant) {
          final trackSid = event.track.sid;
          if (trackSid != null) {
            _removeParticipantTrack(event.participant as RemoteParticipant, trackSid);
          } else {
            // print('RoomAudioDataService: TrackUnsubscribedEvent pour une track avec SID null, participant ${event.participant.identity}');
          }
        }
      } else if (event is ParticipantDisconnectedEvent) {
        _removeAllTracksForParticipant(event.participant.identity);
      }
    });
  }

  void _processExistingTracks() {
    for (var participant in room.remoteParticipants.values) {
      for (var trackPublication in participant.audioTrackPublications) { // Correction: itérer directement sur la liste
        if (trackPublication.track is RemoteAudioTrack && trackPublication.subscribed) { // Correction: isSubscribed -> subscribed
          _addParticipantTrack(participant, trackPublication.track as RemoteAudioTrack);
        }
      }
    }
  }

  void _addParticipantTrack(RemoteParticipant participant, RemoteAudioTrack audioTrack) {
    final participantId = participant.identity;
    final trackSid = audioTrack.sid;

    if (trackSid == null) {
      // print('RoomAudioDataService: Tentative d'ajout d'une track avec SID null pour $participantId. Ignoré.');
      return;
    }
    if (_trackExtractors.containsKey(trackSid)) return;

    // print('RoomAudioDataService: Ajout de la track $trackSid pour $participantId');
    final enhancedTrack = EnhancedRemoteAudioTrack(audioTrack, participantId); // Passer participantId
    _trackExtractors[trackSid] = enhancedTrack;
    
    enhancedTrack.startListening(); // Démarrer l'écoute immédiatement

    final subscription = enhancedTrack.audioDataStream.listen((audioData) {
      // print('RoomAudioDataService: Données reçues pour $participantId - track $trackSid');
      _mixedAudioController.add({participantId: audioData});
    }, onError: (error) {
      // print('RoomAudioDataService: Erreur sur le stream de $participantId (track $trackSid): $error');
    });
    _participantSubscriptions[trackSid] = subscription;
  }

  void _removeParticipantTrack(RemoteParticipant participant, String trackSid) {
    // print('RoomAudioDataService: Suppression de la track $trackSid pour ${participant.identity}');
    final enhancedTrack = _trackExtractors.remove(trackSid);
    if (enhancedTrack != null) {
      enhancedTrack.dispose();
    }
    _participantSubscriptions[trackSid]?.cancel();
    _participantSubscriptions.remove(trackSid);
  }

   void _removeAllTracksForParticipant(String participantId) {
    // print('RoomAudioDataService: Suppression de toutes les tracks pour $participantId');
    final tracksToRemove = <String>[];
    _trackExtractors.forEach((sid, trackWrapper) {
      // Correction: utiliser trackWrapper.participantIdentity
      if (trackWrapper.participantIdentity == participantId) {
        tracksToRemove.add(sid);
      }
    });
    for (var sid in tracksToRemove) {
       final enhancedTrack = _trackExtractors.remove(sid);
       if (enhancedTrack != null) {
         enhancedTrack.dispose();
       }
       _participantSubscriptions[sid]?.cancel();
       _participantSubscriptions.remove(sid);
    }
  }

  Stream<AudioData>? getParticipantAudioStream(String participantId) {
    // Trouver la première track audio pour ce participant
    // Note: un participant peut avoir plusieurs tracks audio. Cette logique est simplifiée.
    for (var entry in _trackExtractors.entries) {
      // Correction: utiliser entry.value.participantIdentity
      if (entry.value.participantIdentity == participantId) {
        return entry.value.audioDataStream;
      }
    }
    return null;
  }

  void dispose() {
    // print('RoomAudioDataService: Dispose appelé');
    for (var extractor in _trackExtractors.values) {
      extractor.dispose();
    }
    _trackExtractors.clear();
    for (var sub in _participantSubscriptions.values) {
      sub.cancel();
    }
    _participantSubscriptions.clear();
    _mixedAudioController.close();
    // Il faudrait aussi se désabonner des événements de la room si ce service a son propre cycle de vie.
  }
}