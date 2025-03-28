import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app/app.dart';
import 'core/utils/log_filter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Charger les variables d'environnement depuis le fichier .env
  await dotenv.load(fileName: ".env");
  
  // Activer le filtre de logs pour supprimer les messages indésirables
  LogFilter.enable();
  
  runApp(const App());
}
