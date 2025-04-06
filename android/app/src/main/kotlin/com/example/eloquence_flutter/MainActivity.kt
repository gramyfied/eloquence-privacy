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
import io.flutter.plugin.common.MethodChannel // Garder pour le canal de permission existant

// Importer notre handler Pigeon
import com.example.eloquence_flutter.AzureSpeechHandler

class MainActivity: FlutterActivity() {
    // Conserver le code de permission
    private val RECORD_AUDIO_PERMISSION_CODE = 101
    // Plus besoin de garder une instance directe du handler ici
    // private var azureSpeechHandler: AzureSpeechHandler? = null
    // private val uiThreadHandler = Handler(Looper.getMainLooper()) // Probablement plus nécessaire pour ce handler

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Enregistrer le handler Pigeon
        // Le contexte et le binaryMessenger sont passés ici.
        AzureSpeechHandler.setUp(flutterEngine.dartExecutor.binaryMessenger, this.applicationContext)

        // Conserver le MethodChannel pour les permissions pour l'instant
        // Note: Il est souvent préférable de gérer les permissions côté Flutter avec permission_handler
        // avant d'appeler les méthodes Pigeon.
        val permissionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.eloquence.app/permissions")
        permissionChannel.setMethodCallHandler { call, result ->
            if (call.method == "requestAudioPermission") {
                if (checkAndRequestPermissions()) {
                    result.success("granted")
                } else {
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
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                println("Permission RECORD_AUDIO accordée.")
            } else {
                println("Permission RECORD_AUDIO refusée.")
            }
        }
    }

    // Le nettoyage des ressources du handler Pigeon est géré par le cycle de vie de l'API Pigeon
    // et la logique interne du handler (stopAndCleanupRecognizer).
    // La méthode cleanUpFlutterEngine peut rester pour d'autres plugins mais ne doit plus
    // référencer l'ancienne méthode releaseResources.
    override fun cleanUpFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        // azureSpeechHandler?.releaseResources() // Supprimer l'appel à l'ancienne méthode
        // azureSpeechHandler = null
        println("Flutter engine cleanup.") // Message générique
    }
}
