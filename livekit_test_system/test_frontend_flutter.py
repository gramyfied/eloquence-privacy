#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test avancé pour diagnostiquer les problèmes frontend Flutter avec LiveKit
Simule exactement ce que fait votre application Flutter
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

# Configuration LiveKit (identique à votre Flutter)
LIVEKIT_CONFIG = {
    "livekit_url": "ws://localhost:7880",
    "api_key": "devkey",
    "api_secret": "devsecret123456789abcdef0123456789abcdef0123456789abcdef",
    "room_name": "eloquence-test-room"  # Même nom que Flutter
}

# Configuration backend (comme Flutter)
BACKEND_CONFIG = {
    "base_url": "http://localhost:8000",
    "session_endpoint": "/api/sessions",
    "livekit_endpoint": "/api/livekit"
}

class FlutterSimulator:
    """Simule exactement le comportement de votre app Flutter"""
    
    def __init__(self):
        self.session_id = None
        self.room = None
        self.audio_received_count = 0
        self.data_received_count = 0
        self.connection_issues = []
        
    async def test_backend_connectivity(self):
        """Test 1: Vérifier la connectivité backend comme Flutter"""
        print("🔍 TEST 1: Connectivité Backend (comme Flutter)")
        print("=" * 50)
        
        try:
            # Test endpoint principal
            response = requests.get(f"{BACKEND_CONFIG['base_url']}/health", timeout=5)
            if response.status_code == 200:
                print("✅ Backend accessible")
            else:
                print(f"❌ Backend erreur: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Backend inaccessible: {e}")
            return False
        
        return True
    
    async def test_session_creation(self):
        """Test 2: Créer une session comme Flutter"""
        print("\n🔍 TEST 2: Création de Session (comme Flutter)")
        print("=" * 50)
        
        try:
            # Données de session comme Flutter
            session_data = {
                "scenario_type": "debat_politique",
                "user_id": "test_user_flutter",
                "difficulty": "intermediate"
            }
            
            response = requests.post(
                f"{BACKEND_CONFIG['base_url']}{BACKEND_CONFIG['session_endpoint']}",
                json=session_data,
                timeout=10
            )
            
            if response.status_code == 201:
                session_info = response.json()
                self.session_id = session_info.get('session_id')
                print(f"✅ Session créée: {self.session_id}")
                print(f"📊 Données session: {json.dumps(session_info, indent=2)}")
                return True
            else:
                print(f"❌ Erreur création session: {response.status_code}")
                print(f"📄 Réponse: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur session: {e}")
            return False
    
    async def test_livekit_token_generation(self):
        """Test 3: Générer token LiveKit comme Flutter"""
        print("\n🔍 TEST 3: Génération Token LiveKit (comme Flutter)")
        print("=" * 50)
        
        if not self.session_id:
            print("❌ Pas de session_id disponible")
            return False
        
        try:
            # Demander token comme Flutter
            token_data = {
                "session_id": self.session_id,
                "participant_identity": "flutter_user",
                "participant_name": "Flutter Test User"
            }
            
            response = requests.post(
                f"{BACKEND_CONFIG['base_url']}{BACKEND_CONFIG['livekit_endpoint']}/token",
                json=token_data,
                timeout=10
            )
            
            if response.status_code == 200:
                token_info = response.json()
                self.livekit_token = token_info.get('token')
                self.room_name = token_info.get('room_name', LIVEKIT_CONFIG['room_name'])
                print(f"✅ Token généré")
                print(f"🏠 Room: {self.room_name}")
                print(f"🎫 Token: {self.livekit_token[:50]}...")
                return True
            else:
                print(f"❌ Erreur token: {response.status_code}")
                print(f"📄 Réponse: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur token: {e}")
            # Fallback: générer token directement comme le test précédent
            print("🔄 Fallback: génération token directe")
            return await self.generate_token_fallback()
    
    async def generate_token_fallback(self):
        """Génère un token directement si le backend ne répond pas"""
        try:
            token_builder = api.AccessToken(LIVEKIT_CONFIG['api_key'], LIVEKIT_CONFIG['api_secret'])
            video_grants = api.VideoGrants(
                room_join=True,
                room=LIVEKIT_CONFIG['room_name'],
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True
            )
            self.livekit_token = token_builder.with_identity("flutter_user_fallback") \
                                .with_name("Flutter Test User Fallback") \
                                .with_grants(video_grants) \
                                .to_jwt()
            self.room_name = LIVEKIT_CONFIG['room_name']
            print("✅ Token fallback généré")
            return True
        except Exception as e:
            print(f"❌ Erreur token fallback: {e}")
            return False
    
    async def test_livekit_connection(self):
        """Test 4: Connexion LiveKit comme Flutter"""
        print("\n🔍 TEST 4: Connexion LiveKit (comme Flutter)")
        print("=" * 50)
        
        if not hasattr(self, 'livekit_token'):
            print("❌ Pas de token LiveKit disponible")
            return False
        
        try:
            # Créer room comme Flutter
            self.room = rtc.Room()
            
            # Callbacks comme Flutter
            self.room.on("connected", self.on_room_connected)
            self.room.on("disconnected", self.on_room_disconnected)
            self.room.on("participant_connected", self.on_participant_connected)
            self.room.on("track_subscribed", self.on_track_subscribed)
            self.room.on("data_received", self.on_data_received)
            
            # Connexion avec timeout comme Flutter
            print(f"🔗 Connexion à {LIVEKIT_CONFIG['livekit_url']}")
            print(f"🏠 Room: {self.room_name}")
            
            await asyncio.wait_for(
                self.room.connect(LIVEKIT_CONFIG['livekit_url'], self.livekit_token),
                timeout=15
            )
            
            print("✅ Connexion LiveKit réussie")
            return True
            
        except asyncio.TimeoutError:
            print("❌ Timeout connexion LiveKit (15s)")
            self.connection_issues.append("Timeout connexion")
            return False
        except Exception as e:
            print(f"❌ Erreur connexion LiveKit: {e}")
            self.connection_issues.append(f"Erreur connexion: {e}")
            return False
    
    def on_room_connected(self):
        """Callback connexion room (comme Flutter)"""
        print("🎉 Room connectée - callback déclenché")
    
    def on_room_disconnected(self, reason):
        """Callback déconnexion room (comme Flutter)"""
        print(f"💔 Room déconnectée: {reason}")
        self.connection_issues.append(f"Déconnexion: {reason}")
    
    def on_participant_connected(self, participant):
        """Callback participant connecté (comme Flutter)"""
        print(f"👤 Participant connecté: {participant.identity}")
    
    def on_track_subscribed(self, track, publication, participant):
        """Callback track reçu (comme Flutter)"""
        print(f"🎵 Track reçu de {participant.identity}: {track.kind}")
        
        if track.kind == rtc.TrackKind.KIND_AUDIO:
            print("🔊 Track AUDIO détecté - démarrage traitement")
            asyncio.create_task(self.process_audio_track(track, participant))
    
    async def process_audio_track(self, track, participant):
        """Traite l'audio reçu (comme Flutter)"""
        try:
            audio_stream = rtc.AudioStream(track)
            print(f"📻 Démarrage stream audio de {participant.identity}")
            
            async for frame_event in audio_stream:
                self.audio_received_count += 1
                
                # Log comme Flutter
                if self.audio_received_count % 100 == 0:
                    frame = frame_event.frame
                    print(f"🎵 Audio reçu: {self.audio_received_count} frames")
                    print(f"   📊 Frame: {frame.samples_per_channel} samples, {frame.sample_rate}Hz")
                
        except Exception as e:
            print(f"❌ Erreur traitement audio: {e}")
            self.connection_issues.append(f"Erreur audio: {e}")
    
    def on_data_received(self, data, participant):
        """Callback données reçues (comme Flutter)"""
        self.data_received_count += 1
        try:
            message = data.decode('utf-8')
            print(f"📨 Message #{self.data_received_count} de {participant.identity}: {message}")
        except:
            print(f"📦 Données binaires #{self.data_received_count} de {participant.identity}: {len(data)} bytes")
    
    async def test_audio_reception(self):
        """Test 5: Réception audio pendant 30 secondes"""
        print("\n🔍 TEST 5: Réception Audio (30 secondes)")
        print("=" * 50)
        
        if not self.room:
            print("❌ Pas de connexion room")
            return False
        
        print("⏳ Attente de réception audio pendant 30 secondes...")
        start_time = time.time()
        initial_count = self.audio_received_count
        
        # Attendre 30 secondes
        while time.time() - start_time < 30:
            await asyncio.sleep(1)
            
            # Log périodique
            if int(time.time() - start_time) % 5 == 0:
                current_count = self.audio_received_count - initial_count
                print(f"⏱️ {int(time.time() - start_time)}s: {current_count} frames audio reçus")
        
        final_count = self.audio_received_count - initial_count
        
        if final_count > 0:
            print(f"✅ Audio reçu: {final_count} frames en 30 secondes")
            return True
        else:
            print("❌ Aucun audio reçu en 30 secondes")
            return False
    
    async def test_backend_audio_trigger(self):
        """Test 6: Déclencher l'audio depuis le backend"""
        print("\n🔍 TEST 6: Déclenchement Audio Backend")
        print("=" * 50)
        
        if not self.session_id:
            print("❌ Pas de session_id")
            return False
        
        try:
            # Envoyer message comme Flutter
            message_data = {
                "session_id": self.session_id,
                "message": "Bonjour, test depuis Flutter simulator",
                "message_type": "user_input"
            }
            
            response = requests.post(
                f"{BACKEND_CONFIG['base_url']}/api/chat/message",
                json=message_data,
                timeout=10
            )
            
            if response.status_code == 200:
                print("✅ Message envoyé au backend")
                print("⏳ Attente de réponse audio...")
                
                # Attendre réponse audio
                initial_count = self.audio_received_count
                start_time = time.time()
                
                while time.time() - start_time < 15:
                    await asyncio.sleep(0.5)
                    if self.audio_received_count > initial_count:
                        print(f"✅ Réponse audio reçue: {self.audio_received_count - initial_count} frames")
                        return True
                
                print("❌ Pas de réponse audio en 15 secondes")
                return False
            else:
                print(f"❌ Erreur envoi message: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur test backend: {e}")
            return False
    
    async def disconnect(self):
        """Déconnexion propre"""
        if self.room:
            await self.room.disconnect()
            print("🔌 Déconnexion LiveKit")

async def main():
    """Test complet du frontend Flutter"""
    print("🔍 DIAGNOSTIC AVANCÉ FRONTEND FLUTTER")
    print("=" * 60)
    print("Simulation exacte du comportement de votre app Flutter")
    print("=" * 60)
    
    simulator = FlutterSimulator()
    results = {}
    
    try:
        # Test 1: Backend
        results['backend'] = await simulator.test_backend_connectivity()
        
        # Test 2: Session
        if results['backend']:
            results['session'] = await simulator.test_session_creation()
        else:
            results['session'] = False
        
        # Test 3: Token
        results['token'] = await simulator.test_livekit_token_generation()
        
        # Test 4: Connexion LiveKit
        if results['token']:
            results['connection'] = await simulator.test_livekit_connection()
            
            if results['connection']:
                # Attendre découverte des participants
                print("\n⏳ Attente découverte participants (10s)...")
                await asyncio.sleep(10)
                
                # Test 5: Réception audio
                results['audio_reception'] = await simulator.test_audio_reception()
                
                # Test 6: Backend trigger
                if results.get('session'):
                    results['backend_trigger'] = await simulator.test_backend_audio_trigger()
                else:
                    results['backend_trigger'] = False
            else:
                results['audio_reception'] = False
                results['backend_trigger'] = False
        else:
            results['connection'] = False
            results['audio_reception'] = False
            results['backend_trigger'] = False
        
        # Rapport final
        print("\n" + "=" * 60)
        print("📊 RAPPORT DE DIAGNOSTIC FLUTTER")
        print("=" * 60)
        
        for test, success in results.items():
            status = "✅ SUCCÈS" if success else "❌ ÉCHEC"
            print(f"{test.upper():20} : {status}")
        
        print(f"\n📈 Statistiques:")
        print(f"  - Audio reçu: {simulator.audio_received_count} frames")
        print(f"  - Messages reçus: {simulator.data_received_count}")
        print(f"  - Problèmes détectés: {len(simulator.connection_issues)}")
        
        if simulator.connection_issues:
            print(f"\n⚠️ Problèmes identifiés:")
            for issue in simulator.connection_issues:
                print(f"  - {issue}")
        
        # Diagnostic
        print(f"\n🔍 DIAGNOSTIC:")
        if not results['backend']:
            print("❌ PROBLÈME: Backend inaccessible")
            print("   Solution: Vérifier que le backend est démarré sur localhost:8000")
        elif not results['connection']:
            print("❌ PROBLÈME: Connexion LiveKit échoue")
            print("   Solution: Vérifier configuration LiveKit dans Flutter")
        elif not results['audio_reception']:
            print("❌ PROBLÈME: Aucun audio reçu")
            print("   Solution: Problème dans le traitement audio Flutter")
        else:
            print("✅ DIAGNOSTIC: Système fonctionnel")
            print("   Le problème est probablement dans l'implémentation Flutter spécifique")
        
    except KeyboardInterrupt:
        print("\n🛑 Test interrompu")
    except Exception as e:
        print(f"\n💥 Erreur critique: {e}")
    finally:
        await simulator.disconnect()

if __name__ == "__main__":
    asyncio.run(main())