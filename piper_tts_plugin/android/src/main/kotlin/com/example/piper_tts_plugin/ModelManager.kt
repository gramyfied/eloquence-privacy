package com.example.piper_tts_plugin

import android.content.Context

class ModelManager(private val context: Context) {
    companion object {
        init {
            System.loadLibrary("piper_tts_plugin")
        }
    }

    external fun getModelPath(modelName: String): String

    fun getModelPathAsync(modelName: String, callback: (String) -> Unit) {
        // Ici, vous pouvez utiliser un thread ou un coroutine pour appeler getModelPath
        // Pour simplifier, nous l'appelons directement
        val path = getModelPath(modelName)
        callback(path)
    }
}
