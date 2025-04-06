import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Enregistrer notre handler Pigeon
    // Récupérer le BinaryMessenger depuis le FlutterViewController
    if let controller = window?.rootViewController as? FlutterViewController {
        AzureSpeechHandler.setUp(messenger: controller.binaryMessenger)
        print("[AppDelegate] AzureSpeechHandler Pigeon setup called.")
    } else {
        print("[AppDelegate] ERREUR: Root view controller is not a FlutterViewController.")
    }
    // Supprimer l'ancienne méthode d'enregistrement si elle existait
    // AzureSpeechHandler.register(with: self.registrar(forPlugin: "AzureSpeechHandler")!) // Supprimé

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Le nettoyage est géré par la logique interne du handler (deinit, stopAndCleanupRecognizer)
  // et le cycle de vie de Pigeon. La méthode applicationWillTerminate peut rester
  // pour d'autres nettoyages si nécessaire, mais ne doit plus appeler detachFromEngine.
  override func applicationWillTerminate(_ application: UIApplication) {
      // if let handler = self.registrar(forPlugin: "AzureSpeechHandler")?.lookupMethod("detachFromEngine") as? AzureSpeechHandler { // Supprimé
      //     handler.detachFromEngine() // Supprimé
      // }
      print("[AppDelegate] Application will terminate.")
      super.applicationWillTerminate(application)
  }

  // Ou si vous ciblez iOS 13+ et utilisez des Scenes, utilisez plutôt :
  // override func sceneWillResignActive(_ scene: UIScene) {
  //     if let handler = (window?.rootViewController as? FlutterViewController)?.pluginRegistrar(forPlugin: "AzureSpeechHandler")?.lookupMethod("detachFromEngine") as? AzureSpeechHandler {
  //         handler.detachFromEngine()
  //     }
  // }
}
