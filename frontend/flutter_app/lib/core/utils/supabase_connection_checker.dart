import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../config/supabase_config.dart';

/// Utilitaire pour vérifier la connexion à Supabase
class SupabaseConnectionChecker {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Vérifie la connexion à Supabase et affiche le résultat
  static Future<bool> checkConnection() async {
    _logger.i('Vérification de la connexion à Supabase...');
    
    try {
      final isConnected = await SupabaseConfig.testConnection();
      
      if (isConnected) {
        _logger.i('✅ Connexion à Supabase établie avec succès');
        _logger.d('URL: ${SupabaseConfig.supabaseUrl}');
        
        if (kDebugMode) {
          print('====================================');
          print('✅ Connexion à Supabase établie avec succès');
          print('URL: ${SupabaseConfig.supabaseUrl}');
          print('====================================');
        }
      } else {
        _logger.e('❌ Échec de la connexion à Supabase');
        
        if (kDebugMode) {
          print('====================================');
          print('❌ Échec de la connexion à Supabase');
          print('URL: ${SupabaseConfig.supabaseUrl}');
          print('Vérifiez vos informations de connexion et votre connexion internet');
          print('====================================');
        }
      }
      
      return isConnected;
    } catch (e) {
      _logger.e('❌ Erreur lors de la vérification de la connexion à Supabase: $e');
      
      if (kDebugMode) {
        print('====================================');
        print('❌ Erreur lors de la vérification de la connexion à Supabase');
        print('Erreur: $e');
        print('====================================');
      }
      
      return false;
    }
  }
  
  /// Affiche les informations de connexion à Supabase
  static void printConnectionInfo() {
    if (kDebugMode) {
      print('====================================');
      print('INFORMATIONS DE CONNEXION SUPABASE');
      print('====================================');
      print('URL: ${SupabaseConfig.supabaseUrl}');
      print('Projet: zjhzwzgslkrociuootph');
      print('Région: eu-west-3 (Paris)');
      print('====================================');
    }
  }
}
