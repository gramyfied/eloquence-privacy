import 'package:piper_tts_plugin/piper_tts_plugin.dart';
import 'package:model_manager/model_manager.dart';

class ModelLoader {
  static Future<String> getModelPath(String modelName) async {
    final modelManager = ModelManager();
    return await modelManager.getModelPath(modelName);
  }
}
