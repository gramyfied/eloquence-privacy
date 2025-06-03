"""
Utilitaires audio utilisant scipy au lieu de pydub pour éviter la dépendance audioop
"""

import numpy as np
import tempfile
import wave
import io
from scipy import signal
from typing import Optional

class AudioSegmentScipy:
    """Remplacement de pydub.AudioSegment utilisant scipy"""
    
    def __init__(self, data: bytes, frame_rate: int, sample_width: int, channels: int):
        self.frame_rate = frame_rate
        self.sample_width = sample_width
        self.channels = channels
        
        # Convertir les bytes en numpy array
        if sample_width == 2:  # 16-bit
            self.audio_data = np.frombuffer(data, dtype=np.int16)
        elif sample_width == 4:  # 32-bit
            self.audio_data = np.frombuffer(data, dtype=np.int32)
        else:
            raise ValueError(f"Sample width {sample_width} non supporté")
    
    @classmethod
    def from_numpy(cls, audio_array: np.ndarray, frame_rate: int, sample_width: int = 2, channels: int = 1):
        """Créer un AudioSegmentScipy depuis un numpy array"""
        if sample_width == 2:
            audio_array = audio_array.astype(np.int16)
        elif sample_width == 4:
            audio_array = audio_array.astype(np.int32)
        
        return cls(audio_array.tobytes(), frame_rate, sample_width, channels)
    
    @classmethod
    def from_wav(cls, wav_buffer: io.BytesIO):
        """Créer un AudioSegmentScipy depuis un buffer WAV"""
        wav_buffer.seek(0)
        with wave.open(wav_buffer, 'rb') as wav_file:
            frame_rate = wav_file.getframerate()
            sample_width = wav_file.getsampwidth()
            channels = wav_file.getnchannels()
            frames = wav_file.readframes(wav_file.getnframes())
        
        return cls(frames, frame_rate, sample_width, channels)
    
    def set_frame_rate(self, new_frame_rate: int) -> 'AudioSegmentScipy':
        """Rééchantillonner l'audio à un nouveau taux d'échantillonnage"""
        if new_frame_rate == self.frame_rate:
            return AudioSegmentScipy(
                self.audio_data.tobytes(),
                self.frame_rate,
                self.sample_width,
                self.channels
            )
        
        # Utiliser scipy.signal.resample pour le rééchantillonnage
        num_samples = len(self.audio_data)
        new_num_samples = int(num_samples * new_frame_rate / self.frame_rate)
        
        # Rééchantillonner
        resampled_data = signal.resample(self.audio_data, new_num_samples)
        
        # Convertir au bon type
        if self.sample_width == 2:
            resampled_data = np.clip(resampled_data, -32768, 32767).astype(np.int16)
        elif self.sample_width == 4:
            resampled_data = np.clip(resampled_data, -2147483648, 2147483647).astype(np.int32)
        
        return AudioSegmentScipy(
            resampled_data.tobytes(),
            new_frame_rate,
            self.sample_width,
            self.channels
        )
    
    def export(self, file_path: str, format: str = "wav"):
        """Exporter l'audio vers un fichier"""
        if format.lower() != "wav":
            raise ValueError("Seul le format WAV est supporté")
        
        with wave.open(file_path, 'wb') as wav_file:
            wav_file.setnchannels(self.channels)
            wav_file.setsampwidth(self.sample_width)
            wav_file.setframerate(self.frame_rate)
            wav_file.writeframes(self.audio_data.tobytes())
    
    def get_array_of_samples(self) -> np.ndarray:
        """Retourner les échantillons audio sous forme de numpy array"""
        return self.audio_data.copy()
    
    def tobytes(self) -> bytes:
        """Retourner les données audio sous forme de bytes"""
        return self.audio_data.tobytes()

def resample_audio_scipy(audio_data: np.ndarray, original_rate: int, target_rate: int) -> np.ndarray:
    """
    Rééchantillonner un signal audio en utilisant scipy
    
    Args:
        audio_data: Signal audio en numpy array
        original_rate: Taux d'échantillonnage original
        target_rate: Taux d'échantillonnage cible
    
    Returns:
        Signal audio rééchantillonné
    """
    if original_rate == target_rate:
        return audio_data
    
    # Calculer le nombre d'échantillons pour le nouveau taux
    num_samples = len(audio_data)
    new_num_samples = int(num_samples * target_rate / original_rate)
    
    # Rééchantillonner avec scipy
    resampled = signal.resample(audio_data, new_num_samples)
    
    # Maintenir le type de données original
    if audio_data.dtype == np.int16:
        resampled = np.clip(resampled, -32768, 32767).astype(np.int16)
    elif audio_data.dtype == np.int32:
        resampled = np.clip(resampled, -2147483648, 2147483647).astype(np.int32)
    elif audio_data.dtype == np.float32:
        resampled = resampled.astype(np.float32)
    
    return resampled

def create_wav_file_scipy(audio_data: np.ndarray, sample_rate: int, file_path: str, sample_width: int = 2):
    """
    Créer un fichier WAV en utilisant scipy/wave
    
    Args:
        audio_data: Données audio en numpy array
        sample_rate: Taux d'échantillonnage
        file_path: Chemin du fichier de sortie
        sample_width: Largeur d'échantillon en bytes (2 pour 16-bit, 4 pour 32-bit)
    """
    # Convertir au bon type selon sample_width
    if sample_width == 2:
        audio_data = audio_data.astype(np.int16)
    elif sample_width == 4:
        audio_data = audio_data.astype(np.int32)
    
    with wave.open(file_path, 'wb') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(sample_width)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio_data.tobytes())

def test_scipy_audio():
    """Tester les fonctions audio scipy"""
    print("Test des utilitaires audio scipy...")
    
    # Créer un signal de test
    duration = 1.0  # 1 seconde
    sample_rate = 16000
    frequency = 440  # La note A
    
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    audio_signal = np.sin(2 * np.pi * frequency * t)
    audio_signal = (audio_signal * 32767).astype(np.int16)
    
    print(f"Signal original: {len(audio_signal)} échantillons à {sample_rate}Hz")
    
    # Test rééchantillonnage
    resampled = resample_audio_scipy(audio_signal, sample_rate, 8000)
    print(f"Signal rééchantillonné: {len(resampled)} échantillons à 8000Hz")
    
    # Test AudioSegmentScipy
    segment = AudioSegmentScipy.from_numpy(audio_signal, sample_rate)
    resampled_segment = segment.set_frame_rate(8000)
    print(f"AudioSegmentScipy: {segment.frame_rate}Hz -> {resampled_segment.frame_rate}Hz")
    
    # Test export WAV
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        create_wav_file_scipy(audio_signal, sample_rate, tmp.name)
        print(f"Fichier WAV créé: {tmp.name}")
    
    print("✅ Tous les tests scipy réussis!")

if __name__ == "__main__":
    test_scipy_audio()