package com.example.eloquence_2_0

import android.content.Context
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL_NATIVE_CHECK = "com.example.eloquence_2_0/native_check"
    private val CHANNEL_AUDIO_CONFIG = "com.example.eloquence_2_0/audio_config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Canal pour vérifier les bibliothèques natives
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NATIVE_CHECK).setMethodCallHandler { call, result ->
            if (call.method == "checkNativeLibraries") {
                result.success(checkNativeLibraries())
            } else {
                result.notImplemented()
            }
        }
        
        // Canal pour obtenir la configuration audio
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_AUDIO_CONFIG).setMethodCallHandler { call, result ->
            if (call.method == "getAudioConfiguration") {
                result.success(getAudioConfiguration())
            } else {
                result.notImplemented()
            }
        }
    }
    
    private fun checkNativeLibraries(): Map<String, Any> {
        val results = mutableMapOf<String, Any>()
        
        try {
            // Vérifier les répertoires de bibliothèques natives
            val libDirs = listOf(
                applicationInfo.nativeLibraryDir,
                "/system/lib",
                "/system/lib64",
                "/vendor/lib",
                "/vendor/lib64"
            )
            
            results["nativeLibraryDir"] = applicationInfo.nativeLibraryDir
            results["libDirs"] = libDirs
            
            // Vérifier la présence de certaines bibliothèques WebRTC
            val webrtcLibs = listOf(
                "libjingle_peerconnection_so.so",
                "libwebrtc.so"
            )
            
            val foundLibs = mutableListOf<String>()
            val missingLibs = mutableListOf<String>()
            
            for (libName in webrtcLibs) {
                var found = false
                for (dir in libDirs) {
                    val libFile = File(dir, libName)
                    if (libFile.exists()) {
                        foundLibs.add("$dir/$libName")
                        found = true
                        break
                    }
                }
                if (!found) {
                    missingLibs.add(libName)
                }
            }
            
            results["foundLibs"] = foundLibs
            results["missingLibs"] = missingLibs
            
            // Vérifier spécifiquement libmagtsync.so
            var magtSyncFound = false
            for (dir in libDirs) {
                val magtSyncFile = File(dir, "libmagtsync.so")
                if (magtSyncFile.exists()) {
                    results["libmagtsync_location"] = "$dir/libmagtsync.so"
                    magtSyncFound = true
                    break
                }
            }
            if (!magtSyncFound) {
                results["libmagtsync_location"] = "NOT FOUND"
            }
            
            // Informations sur l'ABI
            results["supportedAbis"] = Build.SUPPORTED_ABIS.toList()
            results["primaryAbi"] = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
            
        } catch (e: Exception) {
            results["error"] = e.message ?: "Unknown error"
        }
        
        return results
    }
    
    private fun getAudioConfiguration(): Map<String, Any> {
        val audioConfig = mutableMapOf<String, Any>()
        
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            // Mode audio actuel
            audioConfig["audioMode"] = when (audioManager.mode) {
                AudioManager.MODE_NORMAL -> "NORMAL"
                AudioManager.MODE_RINGTONE -> "RINGTONE"
                AudioManager.MODE_IN_CALL -> "IN_CALL"
                AudioManager.MODE_IN_COMMUNICATION -> "IN_COMMUNICATION"
                else -> "UNKNOWN"
            }
            
            // État du haut-parleur
            audioConfig["isSpeakerphoneOn"] = audioManager.isSpeakerphoneOn
            
            // État du microphone muet
            audioConfig["isMicrophoneMute"] = audioManager.isMicrophoneMute
            
            // Volume actuel
            audioConfig["musicVolume"] = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            audioConfig["voiceCallVolume"] = audioManager.getStreamVolume(AudioManager.STREAM_VOICE_CALL)
            
            // Périphériques audio connectés
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_ALL)
                val deviceList = devices.map { device ->
                    mapOf(
                        "type" to device.type,
                        "isSource" to device.isSource,
                        "isSink" to device.isSink,
                        "productName" to device.productName.toString()
                    )
                }
                audioConfig["audioDevices"] = deviceList
            }
            
            // Propriétés audio système
            audioConfig["hasVibrator"] = context.getSystemService(Context.VIBRATOR_SERVICE) != null
            
            // Vérifier si le mode communication est supporté
            try {
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                audioConfig["supportsCommunicationMode"] = true
                audioManager.mode = AudioManager.MODE_NORMAL
            } catch (e: Exception) {
                audioConfig["supportsCommunicationMode"] = false
            }
            
        } catch (e: Exception) {
            audioConfig["error"] = e.message ?: "Unknown error"
        }
        
        return audioConfig
    }
}
