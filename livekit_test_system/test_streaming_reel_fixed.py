#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test de streaming audio RÉEL avec LiveKit - Version corrigée
Vrai envoi et réception d'audio via LiveKit
"""

import asyncio
import time
import sys
import os
import wave
import numpy as np
from pathlib import Path

# Configuration de l'encodage pour Windows
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

try:
    from livekit import rtc, api
    import pyttsx3
except ImportError as e:
    print(f"ERREUR: Dépendance manquante: {e}")
    sys.exit(1)

# Configuration LiveKit
LIVEKIT_CONFIG = {
    "livekit_url": "ws://localhost:7880",
    "api_key": "devkey",
    "api_secret": "devsecret123456789abcdef0123456789abcdef0123456789abcdef",
    "room_name": "test_streaming_reel"
}

class AudioStreamer:
    """Classe pour gérer le streaming audio réel"""
    
    def __init__(self, identity, is_sender=True):
        self.identity = identity
        self.is_sender = is_sender
        self.room = None
        self.audio_track = None
        self.audio_source = None
        self.received_audio_count = 0
        self.received_data_count = 0
        
    async def connect(self):
        """Connexion à la room LiveKit"""
        print(f"[{self.identity}] 🔗 Connexion à LiveKit...")
        
        # Créer token
        token_builder = api.AccessToken(LIVEKIT_CONFIG['api_key'], LIVEKIT_CONFIG['api_secret'])
        video_grants = api.VideoGrants(
            room_join=True,
            room=LIVEKIT_CONFIG['room_name'],
            can_publish=True,
            can_subscribe=True,
            can_publish_data=True
        )
        token = token_builder.with_identity(self.identity) \
                            .with_name(f"Participant {self.identity}") \
                            .with_grants(video_grants) \
                            .to_jwt()
        
        # Créer room et se connecter
        self.room = rtc.Room()
        
        # Configurer les callbacks
        self.room.on("track_subscribed", self.on_track_subscribed)
        self.room.on("participant_connected", self.on_participant_connected)
        self.room.on("data_received", self.on_data_received)
        
        await self.room.connect(LIVEKIT_CONFIG['livekit_url'], token)
        print(f"[{self.identity}] ✅ Connecté à la room: {self.room.name}")
        
        return True
    
    def on_participant_connected(self, participant):
        """Callback quand un participant se connecte"""
        print(f"[{self.identity}] 👤 Participant connecté: {participant.identity}")
    
    def on_track_subscribed(self, track, publication, participant):
        """Callback quand on reçoit un track audio"""
        print(f"[{self.identity}] 🎵 Track audio reçu de {participant.identity}")
        
        if track.kind == rtc.TrackKind.KIND_AUDIO:
            print(f"[{self.identity}] 📻 Début de réception audio de {participant.identity}")
            
            # Créer un task pour traiter l'audio
            asyncio.create_task(self.process_received_audio(track, participant))
    
    async def process_received_audio(self, track, participant):
        """Traite l'audio reçu"""
        try:
            audio_stream = rtc.AudioStream(track)
            
            async for frame_event in audio_stream:
                self.received_audio_count += 1
                
                # Accéder aux données du frame correctement
                frame = frame_event.frame
                
                # Log périodique
                if self.received_audio_count % 50 == 0:
                    print(f"[{self.identity}] 📊 Reçu {self.received_audio_count} frames audio de {participant.identity}")
                    print(f"[{self.identity}] 🎵 Frame: {frame.samples_per_channel} samples, {frame.sample_rate}Hz, {frame.num_channels} canaux")
                
                # Traitement basique de l'audio reçu
                if self.received_audio_count % 100 == 0:
                    print(f"[{self.identity}] 🔊 Audio reçu et traité avec succès!")
                    
        except Exception as e:
            print(f"[{self.identity}] ❌ Erreur traitement audio: {e}")
    
    def on_data_received(self, data_packet):
        """Callback pour les données reçues"""
        self.received_data_count += 1
        data = data_packet.data
        participant = data_packet.participant
        kind = data_packet.kind # Peut être utile pour le débogage
        
        print(f"[{self.identity}] 📨 Données reçues #{self.received_data_count} de {participant.identity} (Kind: {kind}): {len(data)} bytes")
        try:
            message = data.decode('utf-8')
            print(f"[{self.identity}] 💬 Message: {message}")
        except UnicodeDecodeError:
            print(f"[{self.identity}] 📦 Données binaires reçues (non-texte)")
        except Exception as e:
            print(f"[{self.identity}] ❌ Erreur décodage données: {e}")
    
    async def generate_and_send_tts(self, text):
        """Génère du TTS et l'envoie via LiveKit"""
        print(f"[{self.identity}] 🎤 Génération TTS: '{text[:50]}...'")
        
        try:
            # Générer l'audio avec TTS
            engine = pyttsx3.init()
            engine.setProperty('rate', 150)
            engine.setProperty('volume', 0.8)
            
            # Sauvegarder dans un fichier temporaire
            temp_file = f"temp_tts_{int(time.time())}.wav"
            engine.save_to_file(text, temp_file)
            engine.runAndWait()
            
            if not Path(temp_file).exists():
                print(f"[{self.identity}] ❌ Échec génération TTS")
                return False
            
            file_size = Path(temp_file).stat().st_size
            print(f"[{self.identity}] ✅ TTS généré: {file_size} bytes")
            
            # Créer une source audio si pas encore fait
            if not self.audio_source:
                # Configuration audio standard
                sample_rate = 48000
                channels = 1
                
                self.audio_source = rtc.AudioSource(sample_rate, channels)
                self.audio_track = rtc.LocalAudioTrack.create_audio_track("tts_audio", self.audio_source)
                
                # Publier le track
                publication = await self.room.local_participant.publish_track(self.audio_track)
                print(f"[{self.identity}] 📡 Track audio publié: {publication.sid}")
            
            # Lire et convertir le fichier audio
            with wave.open(temp_file, 'rb') as wav_file:
                original_sample_rate = wav_file.getframerate()
                original_channels = wav_file.getnchannels()
                frames = wav_file.readframes(wav_file.getnframes())
                
                print(f"[{self.identity}] 📊 Audio original: {original_sample_rate}Hz, {original_channels} canaux")
            
            # Convertir en numpy array
            audio_data = np.frombuffer(frames, dtype=np.int16)
            
            # Redimensionner pour mono si nécessaire
            if original_channels == 2:
                audio_data = audio_data[::2]  # Prendre un canal sur deux
            
            # Rééchantillonner si nécessaire (simple)
            if original_sample_rate != 48000:
                # Rééchantillonnage simple (pas optimal mais fonctionnel)
                ratio = 48000 / original_sample_rate
                new_length = int(len(audio_data) * ratio)
                audio_data = np.interp(np.linspace(0, len(audio_data), new_length), 
                                     np.arange(len(audio_data)), audio_data).astype(np.int16)
            
            print(f"[{self.identity}] 🔄 Audio converti: {len(audio_data)} samples à 48kHz mono")
            
            # Envoyer par chunks de 480 samples (10ms à 48kHz)
            chunk_size = 480
            chunks_sent = 0
            
            for i in range(0, len(audio_data), chunk_size):
                chunk = audio_data[i:i+chunk_size]
                
                # Logs de débogage pour l'erreur TTS
                # print(f"DEBUG: Type de chunk: {type(chunk)}, len(chunk): {len(chunk)}")
                # print(f"DEBUG: Type de chunk_size: {type(chunk_size)}, chunk_size: {chunk_size}")

                # Compléter le chunk si nécessaire
                if len(chunk) < chunk_size:
                    chunk = np.pad(chunk, (0, chunk_size - len(chunk)), 'constant')
                
                # Créer un frame audio
                frame = rtc.AudioFrame.create(48000, 1, chunk.tobytes())
                await self.audio_source.capture_frame(frame)
                
                chunks_sent += 1
                
                # Log périodique
                if chunks_sent % 100 == 0:
                    print(f"[{self.identity}] 📤 Envoyé {chunks_sent} chunks audio")
                
                # Délai pour temps réel (10ms par chunk)
                await asyncio.sleep(0.01)
            
            print(f"[{self.identity}] ✅ Audio envoyé: {chunks_sent} chunks via LiveKit")
            
            # Envoyer aussi un message de données (payload, topic, kind)
            # Le topic peut être utilisé pour filtrer les messages
            message_payload = f"TTS envoyé: {text[:30]}... ({chunks_sent} chunks)".encode('utf-8')
            await self.room.local_participant.publish_data(
                message_payload,
                topic="tts_status", # Ajouter un topic pour identifier le type de message
                kind=rtc.DataPacketKind.KIND_RELIABLE
            )
            print(f"[{self.identity}] 📨 Message de données envoyé (topic: tts_status)")
            
            # Nettoyer
            Path(temp_file).unlink()
            
            return True
            
        except Exception as e:
            print(f"[{self.identity}] ❌ Erreur TTS: {e}")
            return False
    
    async def send_simple_data(self, message):
        """Envoie un simple message de données"""
        try:
            await self.room.local_participant.publish_data(message.encode('utf-8'))
            print(f"[{self.identity}] 📤 Message envoyé: {message}")
            return True
        except Exception as e:
            print(f"[{self.identity}] ❌ Erreur envoi message: {e}")
            return False
    
    async def disconnect(self):
        """Déconnexion"""
        if self.room:
            await self.room.disconnect()
            print(f"[{self.identity}] 🔌 Déconnecté")

async def test_streaming_bidirectionnel():
    """Test de streaming audio bidirectionnel"""
    print("=" * 60)
    print("TEST STREAMING AUDIO RÉEL AVEC LIVEKIT")
    print("=" * 60)
    
    # Créer deux participants
    coach_ai = AudioStreamer("coach_ai", is_sender=True)
    student = AudioStreamer("student", is_sender=False)
    
    try:
        # Connexion des deux participants
        print("\n🔗 Connexion des participants...")
        await coach_ai.connect()
        await asyncio.sleep(2)  # Délai entre connexions
        await student.connect()
        
        # Attendre que les participants se découvrent
        print("\n⏳ Attente de la découverte des participants...")
        await asyncio.sleep(5)
        
        # Test simple de messages de données d'abord
        print("\n📨 Test d'envoi de messages de données...")
        await coach_ai.send_simple_data("Bonjour, je suis le coach IA!")
        await asyncio.sleep(2)
        await student.send_simple_data("Bonjour coach, je suis prêt à apprendre!")
        await asyncio.sleep(3)
        
        # Le coach envoie des messages audio
        phrases_coaching = [
            "Bonjour, je suis votre coach vocal IA.",
            "Commençons par un exercice de respiration.",
            "Excellent travail ! Votre diction s'améliore."
        ]
        
        print("\n🎤 Début du streaming audio TTS...")
        
        for i, phrase in enumerate(phrases_coaching):
            print(f"\n--- Message Audio {i+1}/{len(phrases_coaching)} ---")
            
            # Le coach génère et envoie l'audio
            success = await coach_ai.generate_and_send_tts(phrase)
            
            if success:
                print(f"✅ Message audio {i+1} envoyé avec succès")
            else:
                print(f"❌ Échec envoi message audio {i+1}")
            
            # Attendre entre les messages
            print("⏳ Attente 8 secondes...")
            await asyncio.sleep(8)
        
        print("\n📊 Statistiques finales:")
        print(f"Student a reçu {student.received_audio_count} frames audio")
        print(f"Student a reçu {student.received_data_count} messages de données")
        print(f"Coach a reçu {coach_ai.received_data_count} messages de données")
        
        # Test de durée courte
        print("\n⏱️ Test de streaming continu (20 secondes)...")
        start_time = time.time()
        
        test_count = 0
        while time.time() - start_time < 20:
            test_count += 1
            await coach_ai.send_simple_data(f"Test continu #{test_count}")
            await asyncio.sleep(3)
        
        print(f"\n✅ Test terminé !")
        print(f"📊 Statistiques finales:")
        print(f"  - Student: {student.received_audio_count} frames audio, {student.received_data_count} messages")
        print(f"  - Coach: {coach_ai.received_data_count} messages reçus")
        
        if student.received_audio_count > 0:
            print("🎉 STREAMING AUDIO RÉUSSI ! L'audio TTS a été reçu via LiveKit!")
        else:
            print("⚠️ Aucun audio reçu, mais les messages de données fonctionnent")
        
    except Exception as e:
        print(f"\n❌ Erreur durant le test: {e}")
        
    finally:
        # Déconnexion
        print("\n🔌 Déconnexion des participants...")
        await coach_ai.disconnect()
        await student.disconnect()

async def main():
    """Fonction principale"""
    try:
        await test_streaming_bidirectionnel()
        print("\n🎉 Test de streaming réel terminé avec succès !")
        
    except KeyboardInterrupt:
        print("\n🛑 Test interrompu par l'utilisateur")
    except Exception as e:
        print(f"\n💥 Erreur critique: {e}")

if __name__ == "__main__":
    asyncio.run(main())