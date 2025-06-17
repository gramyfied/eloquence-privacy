#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test FINAL pour reproduire exactement le problème Flutter
Utilise les vraies données du backend
"""

import asyncio
import time
import sys
import os
import json
from pathlib import Path

# Configuration de l'encodage pour Windows
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

try:
    from livekit import rtc, api
    import requests
except ImportError as e:
    print(f"ERREUR: Dépendance manquante: {e}")
    sys.exit(1)

# Configuration backend
BACKEND_CONFIG = {
    "base_url": "http://localhost:8000",
    "session_endpoint": "/api/sessions"
}

class FlutterFinalTest:
    """Test final avec les vraies données du backend"""
    
    def __init__(self):
        self.session_data = None
        self.room = None
        self.audio_received_count = 0
        self.data_received_count = 0
        
    async def get_real_session_data(self):
        """Récupère les vraies données de session du backend"""
        print("🔍 RÉCUPÉRATION DES DONNÉES RÉELLES DU BACKEND")
        print("=" * 60)
        
        try:
            # Données exactes comme Flutter
            session_request = {
                "scenario_id": "debat_politique",
                "user_id": "flutter_test_user",
                "language": "fr",
                "goal": "Test de streaming audio"
            }
            
            print(f"📤 Requête session: {json.dumps(session_request, indent=2)}")
            
            response = requests.post(
                f"{BACKEND_CONFIG['base_url']}{BACKEND_CONFIG['session_endpoint']}",
                json=session_request,
                timeout=15
            )
            
            print(f"📥 Status: {response.status_code}")
            
            if response.status_code in [200, 201]:  # Accepter 200 ET 201
                self.session_data = response.json()
                
                print("✅ Session créée avec succès!")
                print(f"📊 Données complètes:")
                print(json.dumps(self.session_data, indent=2))
                
                # Extraire les infos importantes
                session_id = self.session_data.get('session_id')
                livekit_url = self.session_data.get('livekit_url')
                livekit_token = self.session_data.get('livekit_token')
                room_name = self.session_data.get('room_name')
                
                print(f"\n🎯 INFOS CLÉS:")
                print(f"   Session ID: {session_id}")
                print(f"   LiveKit URL: {livekit_url}")
                print(f"   Room: {room_name}")
                print(f"   Token: {'PRÉSENT' if livekit_token else 'ABSENT'}")
                
                return True
            else:
                print(f"❌ Erreur: {response.status_code}")
                print(f"📄 Réponse: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur: {e}")
            return False
    
    async def test_livekit_with_real_data(self):
        """Test LiveKit avec les vraies données du backend"""
        print("\n🔍 TEST LIVEKIT AVEC DONNÉES RÉELLES")
        print("=" * 60)
        
        if not self.session_data:
            print("❌ Pas de données de session")
            return False
        
        livekit_url = self.session_data.get('livekit_url')
        livekit_token = self.session_data.get('livekit_token')
        room_name = self.session_data.get('room_name')
        
        # Convertir HTTP en WebSocket si nécessaire
        if livekit_url.startswith('http://'):
            ws_url = livekit_url.replace('http://', 'ws://')
        elif livekit_url.startswith('https://'):
            ws_url = livekit_url.replace('https://', 'wss://')
        else:
            ws_url = livekit_url
        
        print(f"🔗 URL originale: {livekit_url}")
        print(f"🔗 URL WebSocket: {ws_url}")
        print(f"🏠 Room: {room_name}")
        
        try:
            # Créer room
            self.room = rtc.Room()
            
            # Callbacks
            self.room.on("connected", self.on_room_connected)
            self.room.on("disconnected", self.on_room_disconnected)
            self.room.on("participant_connected", self.on_participant_connected)
            self.room.on("track_subscribed", self.on_track_subscribed)
            self.room.on("data_received", self.on_data_received)
            
            print("🔄 Tentative de connexion...")
            
            # Connexion avec timeout
            await asyncio.wait_for(
                self.room.connect(ws_url, livekit_token),
                timeout=25
            )
            
            print("✅ Connexion LiveKit réussie!")
            return True
            
        except asyncio.TimeoutError:
            print("❌ Timeout connexion (25s)")
            return False
        except Exception as e:
            print(f"❌ Erreur connexion: {e}")
            return False
    
    def on_room_connected(self):
        print("🎉 ROOM CONNECTÉE!")
    
    def on_room_disconnected(self, reason):
        print(f"💔 Room déconnectée: {reason}")
    
    def on_participant_connected(self, participant):
        print(f"👤 Participant connecté: {participant.identity}")
        if "backend-agent" in participant.identity:
            print("🤖 AGENT BACKEND DÉTECTÉ!")
    
    def on_track_subscribed(self, track, publication, participant):
        print(f"🎵 TRACK REÇU de {participant.identity}: {track.kind}")
        
        if track.kind == rtc.TrackKind.KIND_AUDIO:
            print("🔊 TRACK AUDIO DÉTECTÉ!")
            asyncio.create_task(self.process_audio_track(track, participant))
    
    async def process_audio_track(self, track, participant):
        try:
            audio_stream = rtc.AudioStream(track)
            print(f"📻 STREAM AUDIO DÉMARRÉ de {participant.identity}")
            
            async for frame_event in audio_stream:
                self.audio_received_count += 1
                
                if self.audio_received_count % 25 == 0:
                    frame = frame_event.frame
                    print(f"🎵 AUDIO: {self.audio_received_count} frames de {participant.identity}")
                    print(f"   📊 {frame.samples_per_channel} samples, {frame.sample_rate}Hz")
                
        except Exception as e:
            print(f"❌ Erreur audio: {e}")
    
    def on_data_received(self, data, participant):
        self.data_received_count += 1
        try:
            message = data.decode('utf-8')
            print(f"📨 MESSAGE #{self.data_received_count}: {message}")
        except:
            print(f"📦 DONNÉES #{self.data_received_count}: {len(data)} bytes")
    
    async def wait_for_backend_agent(self):
        """Attendre que l'agent backend se connecte et envoie de l'audio"""
        print("\n🔍 ATTENTE DE L'AGENT BACKEND")
        print("=" * 60)
        
        print("⏳ Attente connexion agent backend (20 secondes)...")
        await asyncio.sleep(20)
        
        print("⏳ Test de réception audio (60 secondes)...")
        start_time = time.time()
        initial_count = self.audio_received_count
        
        while time.time() - start_time < 60:
            await asyncio.sleep(2)
            
            current_count = self.audio_received_count - initial_count
            elapsed = int(time.time() - start_time)
            
            if elapsed % 10 == 0:
                print(f"⏱️ {elapsed}s: {current_count} frames audio reçus")
        
        final_count = self.audio_received_count - initial_count
        
        if final_count > 0:
            print(f"✅ SUCCÈS: {final_count} frames audio reçus!")
            return True
        else:
            print("❌ ÉCHEC: Aucun audio reçu")
            return False
    
    async def send_chat_message(self):
        """Envoyer un message chat pour déclencher l'IA"""
        print("\n🔍 DÉCLENCHEMENT IA VIA CHAT")
        print("=" * 60)
        
        if not self.session_data:
            print("❌ Pas de session")
            return False
        
        session_id = self.session_data.get('session_id')
        
        try:
            message_data = {
                "session_id": session_id,
                "message": "Bonjour, parlons de l'environnement et du réchauffement climatique",
                "message_type": "user_input"
            }
            
            print(f"📤 Envoi message: {message_data['message']}")
            
            response = requests.post(
                f"{BACKEND_CONFIG['base_url']}/chat/message",
                json=message_data,
                timeout=15
            )
            
            if response.status_code == 200:
                print("✅ Message envoyé!")
                print("⏳ Attente réponse IA (30s)...")
                
                initial_count = self.audio_received_count
                start_time = time.time()
                
                while time.time() - start_time < 30:
                    await asyncio.sleep(1)
                    if self.audio_received_count > initial_count:
                        new_frames = self.audio_received_count - initial_count
                        print(f"✅ RÉPONSE IA REÇUE: {new_frames} frames!")
                        return True
                
                print("❌ Pas de réponse IA")
                return False
            else:
                print(f"❌ Erreur envoi: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur chat: {e}")
            return False
    
    async def disconnect(self):
        if self.room:
            await self.room.disconnect()
            print("🔌 Déconnexion")

async def main():
    """Test final complet"""
    print("🎯 TEST FINAL - REPRODUCTION EXACTE DU PROBLÈME FLUTTER")
    print("=" * 80)
    
    test = FlutterFinalTest()
    
    try:
        # Étape 1: Récupérer les vraies données
        if not await test.get_real_session_data():
            print("💥 ÉCHEC: Impossible de créer une session")
            return
        
        # Étape 2: Se connecter à LiveKit
        if not await test.test_livekit_with_real_data():
            print("💥 ÉCHEC: Impossible de se connecter à LiveKit")
            return
        
        # Étape 3: Attendre l'agent backend
        audio_received = await test.wait_for_backend_agent()
        
        # Étape 4: Tester le chat
        chat_works = await test.send_chat_message()
        
        # Rapport final
        print("\n" + "=" * 80)
        print("📊 RAPPORT FINAL")
        print("=" * 80)
        
        print(f"✅ Session créée: OUI")
        print(f"✅ LiveKit connecté: OUI")
        print(f"{'✅' if audio_received else '❌'} Audio reçu: {'OUI' if audio_received else 'NON'}")
        print(f"{'✅' if chat_works else '❌'} Chat IA: {'OUI' if chat_works else 'NON'}")
        
        print(f"\n📈 Statistiques:")
        print(f"  - Frames audio: {test.audio_received_count}")
        print(f"  - Messages: {test.data_received_count}")
        
        print(f"\n🎯 CONCLUSION:")
        if audio_received and chat_works:
            print("✅ SYSTÈME COMPLÈTEMENT FONCTIONNEL!")
            print("   Le problème est dans votre code Flutter spécifique")
            print("   Vérifiez les URLs et callbacks dans Flutter")
        elif audio_received:
            print("⚠️ Audio fonctionne mais pas le chat")
            print("   L'agent backend envoie de l'audio automatiquement")
        else:
            print("❌ L'agent backend ne se connecte pas ou n'envoie pas d'audio")
            print("   Problème dans le backend ou la configuration LiveKit")
        
        # Données pour Flutter
        if test.session_data:
            print(f"\n💡 DONNÉES POUR VOTRE FLUTTER:")
            print(f"   URL LiveKit: {test.session_data.get('livekit_url')}")
            print(f"   Room: {test.session_data.get('room_name')}")
            print(f"   Utilisez ces URLs exactes dans Flutter!")
        
    except KeyboardInterrupt:
        print("\n🛑 Test interrompu")
    except Exception as e:
        print(f"\n💥 Erreur: {e}")
    finally:
        await test.disconnect()

if __name__ == "__main__":
    asyncio.run(main())