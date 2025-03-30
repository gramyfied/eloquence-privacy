package com.example.eloquence_flutter

import android.Manifest
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel // Ajout de l'import manquant
// Supprimer les imports spécifiques à Azure non nécessaires ici
// import com.microsoft.cognitiveservices.speech.*
// import com.microsoft.cognitiveservices.speech.audio.AudioConfig
// import java.util.concurrent.Executors
// import java.util.concurrent.Future // Revenir à Future

// Importer notre handler
import com.example.eloquence_flutter.AzureSpeechHandler

class MainActivity: FlutterActivity() {
    // Conserver uniquement le code de permission et l'initialisation du handler
    private val RECORD_AUDIO_PERMISSION_CODE = 101
    private var azureSpeechHandler: AzureSpeechHandler? = null
    private val uiThreadHandler = Handler(Looper.getMainLooper()) // Garder pour sendEvent si nécessaire dans MainActivity

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Instancier et démarrer notre handler Azure
        azureSpeechHandler = AzureSpeechHandler(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        azureSpeechHandler?.startListening()

        // Configurer un MethodChannel séparé pour les permissions si nécessaire,
        // ou laisser Flutter gérer les permissions avant d'appeler le natif.
        // Pour l'instant, on garde la logique de permission ici.
        val permissionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.eloquence.app/permissions")
        permissionChannel.setMethodCallHandler { call, result ->
            if (call.method == "requestAudioPermission") {
                if (checkAndRequestPermissions()) {
                    result.success("granted")
                } else {
                    // Le résultat sera géré dans onRequestPermissionsResult
                    // On pourrait stocker le `result` pour l'appeler plus tard
                    result.success("pending") // Indiquer que la demande est en cours
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // Conserver la logique de permission
    private fun checkAndRequestPermissions(): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), RECORD_AUDIO_PERMISSION_CODE)
            return false
        }
        return true
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RECORD_AUDIO_PERMISSION_CODE) {
            // Informer Flutter du résultat de la permission via un EventChannel ou MethodChannel dédié si nécessaire
            // Pour l'instant, on suppose que Flutter gère la vérification après la demande.
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                println("Permission RECORD_AUDIO accordée.")
                // On pourrait envoyer un événement ici si Flutter écoute
            } else {
                println("Permission RECORD_AUDIO refusée.")
                // On pourrait envoyer un événement ici si Flutter écoute
            }
        }
    }

    // Supprimer les méthodes spécifiques à Azure : initializeAzureSpeech, createAndSetupRecognizer, startRecognition, stopRecognition, synthesizeText
    // Supprimer le helper sendEvent s'il n'est plus utilisé que par les méthodes supprimées

    override fun cleanUpFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        // Appeler la méthode de libération complète des ressources du handler
        azureSpeechHandler?.releaseResources() // Appel à la méthode de nettoyage final
        azureSpeechHandler = null
        println("AzureSpeechHandler resources released and handler detached.")
    }
}
