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
import io.flutter.plugin.common.MethodChannel // Import correct
// Supprimer les imports spécifiques à Azure non nécessaires ici

// Importer notre handler
import com.example.eloquence_flutter.AzureSpeechHandler

class MainActivity: FlutterActivity() {
    // Conserver uniquement le code de permission et l'initialisation du handler
    private val RECORD_AUDIO_PERMISSION_CODE = 101
    private var azureSpeechHandler: AzureSpeechHandler? = null
    private val uiThreadHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Instancier et démarrer notre handler Azure
        azureSpeechHandler = AzureSpeechHandler(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        azureSpeechHandler?.startListening()

        // Configurer un MethodChannel séparé pour les permissions si nécessaire,
        // ou laisser Flutter gérer les permissions avant d'appeler le natif.
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

    // Appeler la méthode de nettoyage final du handler
    override fun cleanUpFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        azureSpeechHandler?.releaseResources() // Appel correct
        azureSpeechHandler = null
        println("AzureSpeechHandler resources released and handler detached.")
    }
}
