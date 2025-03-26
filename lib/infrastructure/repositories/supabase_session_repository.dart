import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSessionRepository {
  final SupabaseClient _supabaseClient;

  SupabaseSessionRepository(this._supabaseClient);

  /// Récupère l'historique des sessions d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserSessions(String userId, {int limit = 20}) async {
    final response = await _supabaseClient
        .from('sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Récupère une session spécifique par son ID
  Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    final response = await _supabaseClient
        .from('sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    
    return response;
  }

  /// Récupère les sessions filtrées par catégorie
  Future<List<Map<String, dynamic>>> getSessionsByCategory(String userId, String category) async {
    final response = await _supabaseClient
        .from('sessions')
        .select()
        .eq('user_id', userId)
        .eq('category', category)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Récupère les sessions dans une plage de dates
  Future<List<Map<String, dynamic>>> getSessionsByDateRange(
    String userId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    final response = await _supabaseClient
        .from('sessions')
        .select()
        .eq('user_id', userId)
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', endDate.toIso8601String())
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Enregistre une nouvelle session
  Future<Map<String, dynamic>> saveSession({
    required String userId,
    required String category,
    String? scenario,
    required int duration,
    required int difficulty,
    required int score,
    String? audioUrl,
    double? pronunciationScore,
    double? accuracyScore,
    double? fluencyScore,
    double? completenessScore,
    double? prosodyScore,
    String? transcription,
    String? feedback,
    String? articulationSubcategory,
    String? exerciseId,
  }) async {
    final sessionData = {
      'user_id': userId,
      'category': category,
      'scenario': scenario,
      'duration': duration,
      'difficulty': difficulty,
      'score': score,
      'audio_url': audioUrl,
      'pronunciation_score': pronunciationScore,
      'accuracy_score': accuracyScore,
      'fluency_score': fluencyScore,
      'completeness_score': completenessScore,
      'prosody_score': prosodyScore,
      'transcription': transcription,
      'feedback': feedback,
      'articulation_subcategory': articulationSubcategory,
      'exercise_id': exerciseId,
    };
    
    // Supprimer les valeurs nulles
    sessionData.removeWhere((key, value) => value == null);
    
    final response = await _supabaseClient
        .from('sessions')
        .insert(sessionData)
        .select()
        .single();
    
    return response;
  }

  /// Met à jour une session existante
  Future<void> updateSession({
    required String sessionId,
    String? category,
    String? scenario,
    int? duration,
    int? difficulty,
    int? score,
    String? audioUrl,
    double? pronunciationScore,
    double? accuracyScore,
    double? fluencyScore,
    double? completenessScore,
    double? prosodyScore,
    String? transcription,
    String? feedback,
    String? articulationSubcategory,
  }) async {
    final updates = <String, dynamic>{};
    
    if (category != null) updates['category'] = category;
    if (scenario != null) updates['scenario'] = scenario;
    if (duration != null) updates['duration'] = duration;
    if (difficulty != null) updates['difficulty'] = difficulty;
    if (score != null) updates['score'] = score;
    if (audioUrl != null) updates['audio_url'] = audioUrl;
    if (pronunciationScore != null) updates['pronunciation_score'] = pronunciationScore;
    if (accuracyScore != null) updates['accuracy_score'] = accuracyScore;
    if (fluencyScore != null) updates['fluency_score'] = fluencyScore;
    if (completenessScore != null) updates['completeness_score'] = completenessScore;
    if (prosodyScore != null) updates['prosody_score'] = prosodyScore;
    if (transcription != null) updates['transcription'] = transcription;
    if (feedback != null) updates['feedback'] = feedback;
    if (articulationSubcategory != null) updates['articulation_subcategory'] = articulationSubcategory;
    
    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      
      await _supabaseClient
          .from('sessions')
          .update(updates)
          .eq('id', sessionId);
    }
  }

  /// Supprime une session
  Future<void> deleteSession(String sessionId) async {
    await _supabaseClient
        .from('sessions')
        .delete()
        .eq('id', sessionId);
  }

  /// Télécharge un fichier audio pour une session
  Future<String> uploadSessionAudio(String userId, String sessionId, List<int> audioBytes, String fileName) async {
    final fileExt = fileName.split('.').last;
    final filePath = 'sessions/$userId/$sessionId.$fileExt';
    
    await _supabaseClient
        .storage
        .from('audio')
        .uploadBinary(filePath, Uint8List.fromList(audioBytes));
    
    final audioUrl = _supabaseClient
        .storage
        .from('audio')
        .getPublicUrl(filePath);
    
    // Mettre à jour la session avec l'URL audio
    await updateSession(
      sessionId: sessionId,
      audioUrl: audioUrl,
    );
    
    return audioUrl;
  }
}
