package com.example.whisper_stt_plugin

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Gestionnaire de modèles pour Whisper.
 * Gère le téléchargement, la mise en cache et le chargement des modèles.
 */
class ModelManager(private val context: Context) {
    companion object {
        private const val TAG = "WhisperModelManager"
        private const val MODELS_DIR = "whisper_models"
        
        // URL des modèles Whisper
        private val MODEL_URLS = mapOf(
            "tiny" to "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
            "base" to "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
            "small" to "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
            "medium" to "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin",
            "large" to "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large.bin"
        )
        
        // Tailles approximatives des modèles en Mo
        private val MODEL_SIZES = mapOf(
            "tiny" to 75,
            "base" to 142,
            "small" to 466,
            "medium" to 1500,
            "large" to 3000
        )
    }
    
    private val isDownloading = AtomicBoolean(false)
    private var downloadProgress = 0
    private var downloadListener: ((Int) -> Unit)? = null
    
    /**
     * Obtient le chemin du répertoire des modèles.
     */
    private fun getModelsDir(): File {
        val modelsDir = File(context.filesDir, MODELS_DIR)
        if (!modelsDir.exists()) {
            modelsDir.mkdirs()
        }
        return modelsDir
    }
    
    /**
     * Vérifie si un modèle est déjà téléchargé.
     */
    fun isModelDownloaded(modelName: String): Boolean {
        val modelFile = File(getModelsDir(), "ggml-$modelName.bin")
        return modelFile.exists() && modelFile.length() > 0
    }
    
    /**
     * Obtient le chemin d'un modèle.
     */
    fun getModelPath(modelName: String): String {
        return File(getModelsDir(), "ggml-$modelName.bin").absolutePath
    }
    
    /**
     * Télécharge un modèle.
     */
    suspend fun downloadModel(modelName: String): Boolean = withContext(Dispatchers.IO) {
        if (isDownloading.getAndSet(true)) {
            Log.w(TAG, "Un téléchargement est déjà en cours")
            return@withContext false
        }
        
        try {
            val modelUrl = MODEL_URLS[modelName] ?: throw IllegalArgumentException("Modèle inconnu: $modelName")
            val modelFile = File(getModelsDir(), "ggml-$modelName.bin")
            
            // Vérifier si le modèle existe déjà
            if (modelFile.exists() && modelFile.length() > 0) {
                Log.i(TAG, "Le modèle $modelName est déjà téléchargé")
                return@withContext true
            }
            
            // Créer une connexion HTTP
            val url = URL(modelUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.connect()
            
            // Vérifier le code de réponse
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                Log.e(TAG, "Erreur lors du téléchargement du modèle: ${connection.responseCode}")
                return@withContext false
            }
            
            // Obtenir la taille du fichier
            val fileSize = connection.contentLength
            
            // Créer un tampon pour le téléchargement
            val buffer = ByteArray(8192)
            var bytesRead: Int
            var totalBytesRead = 0
            
            // Télécharger le fichier
            connection.inputStream.use { input ->
                FileOutputStream(modelFile).use { output ->
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        totalBytesRead += bytesRead
                        
                        // Mettre à jour la progression
                        val progress = if (fileSize > 0) {
                            (totalBytesRead * 100 / fileSize)
                        } else {
                            -1
                        }
                        
                        if (progress != downloadProgress) {
                            downloadProgress = progress
                            withContext(Dispatchers.Main) {
                                downloadListener?.invoke(progress)
                            }
                        }
                    }
                }
            }
            
            Log.i(TAG, "Modèle $modelName téléchargé avec succès")
            return@withContext true
        } catch (e: Exception) {
            Log.e(TAG, "Erreur lors du téléchargement du modèle", e)
            return@withContext false
        } finally {
            isDownloading.set(false)
            downloadProgress = 0
        }
    }
    
    /**
     * Définit un écouteur pour la progression du téléchargement.
     */
    fun setDownloadListener(listener: (Int) -> Unit) {
        this.downloadListener = listener
    }
    
    /**
     * Supprime un modèle.
     */
    fun deleteModel(modelName: String): Boolean {
        val modelFile = File(getModelsDir(), "ggml-$modelName.bin")
        return if (modelFile.exists()) {
            modelFile.delete()
        } else {
            false
        }
    }
    
    /**
     * Obtient la taille approximative d'un modèle en Mo.
     */
    fun getModelSize(modelName: String): Int {
        return MODEL_SIZES[modelName] ?: 0
    }
    
    /**
     * Liste tous les modèles disponibles.
     */
    fun listAvailableModels(): List<String> {
        return MODEL_URLS.keys.toList()
    }
    
    /**
     * Liste tous les modèles téléchargés.
     */
    fun listDownloadedModels(): List<String> {
        val modelsDir = getModelsDir()
        return modelsDir.listFiles()
            ?.filter { it.name.startsWith("ggml-") && it.name.endsWith(".bin") }
            ?.map { it.name.removePrefix("ggml-").removeSuffix(".bin") }
            ?: emptyList()
    }
}
