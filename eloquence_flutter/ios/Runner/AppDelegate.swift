import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Enregistrer notre plugin AzureSpeechHandler
    AzureSpeechHandler.register(with: self.registrar(forPlugin: "AzureSpeechHandler")!)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Ajouter la méthode pour détacher le plugin lors de la fermeture de l'engine
  override func applicationWillTerminate(_ application: UIApplication) {
      if let handler = self.registrar(forPlugin: "AzureSpeechHandler")?.lookupMethod("detachFromEngine") as? AzureSpeechHandler {
          handler.detachFromEngine()
      }
      super.applicationWillTerminate(application)
  }

  // Ou si vous ciblez iOS 13+ et utilisez des Scenes, utilisez plutôt :
  // override func sceneWillResignActive(_ scene: UIScene) {
  //     if let handler = (window?.rootViewController as? FlutterViewController)?.pluginRegistrar(forPlugin: "AzureSpeechHandler")?.lookupMethod("detachFromEngine") as? AzureSpeechHandler {
  //         handler.detachFromEngine()
  //     }
  // }
}
