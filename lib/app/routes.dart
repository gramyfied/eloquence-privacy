class AppRoutes {
  static const String home = '/home';
  static const String auth = '/auth';
  static const String welcome = '/welcome';
  static const String authScreen = '/authScreen';
  static const String exerciseCategories = '/exercise_categories';
  static const String exercise = '/exercise';
  static const String exerciseResult = '/exercise_result';
  static const String statistics = '/statistics';
  static const String profile = '/profile';
  static const String history = '/history';
  static const String debug = '/debug';

  // Routes spécifiques aux exercices
  static const String exerciseLungCapacity = '/exercise/lung-capacity/:exerciseId';
  static const String exerciseArticulation = '/exercise/articulation/:exerciseId';
  static const String exerciseBreathing = '/exercise/breathing/:exerciseId';
  static const String exerciseVolumeControl = '/exercise/volume-control/:exerciseId';
  static const String exerciseResonance = '/exercise/resonance/:exerciseId';
  static const String exerciseProjection = '/exercise/projection/:exerciseId';
  // Ajoutez d'autres routes spécifiques ici si nécessaire
}
