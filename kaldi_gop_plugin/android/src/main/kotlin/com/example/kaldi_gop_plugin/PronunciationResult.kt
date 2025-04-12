package com.example.kaldi_gop_plugin

/**
 * Classe représentant le résultat d'évaluation de prononciation pour un phonème.
 *
 * @property phoneme Le phonème évalué
 * @property score Le score de prononciation (0.0 à 1.0, où 1.0 est parfait)
 * @property confidence Le niveau de confiance de l'évaluation (0.0 à 1.0)
 */
class PronunciationResult(
    val phoneme: String,
    val score: Float,
    val confidence: Float
) {
    override fun toString(): String {
        return "PronunciationResult(phoneme='$phoneme', score=$score, confidence=$confidence)"
    }
}
