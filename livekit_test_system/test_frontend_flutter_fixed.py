#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test avancé pour diagnostiquer les problèmes frontend Flutter avec LiveKit - VERSION CORRIGÉE
Utilise la structure exacte attendue par le backend
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
    "room_name": "eloquence-test-room"
}

# Configuration backend (comme Flutter)
BACKEND_CONFIG = {
    "base_url": "http://localhost:8000",
    "session_endpoint": "/api/sessions",
    "livekit_endpoint": "/livekit"
}

class FlutterSimulatorFixed:
    """Simule exactement le comportement de votre app Flutter - VERSION CORRIGÉE"""
    
    def __init__(self):
        self.session_id = None
        self.room = None
        self.audio_received_count = 0
        self.data_received_count = 0
        self.connection_issues = []
        self.livekit_token = None
        self.room_name = None
        
    async def test_backend_connectivity(self):
        """Test 1: Vérifier la connectivité backend comme Flutter"""
        print("🔍 TEST 1: Connectivité Backend (comme Flutter)")
        print("=" * 50)
        
        try:
            # Test endpoint principal
            response = requests.get(f"{BACKEND_CONFIG['base_url']}/health", timeout=5)
            if response.status_code == 200:
                health_data = response.json()
                print("✅ Backend accessible")
                print(f"📊 Status: {health_data}")
                return True
            else:
                print(f"❌ Backend erreur: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Backend inaccessible: {e}")
            return False
    
    async def test_session_creation(self):
        """Test 2: Créer une session comme Flutter - STRUCTURE CORRIGÉE"""
        print("\n🔍 TEST 2: Création de Session (structure corrigée)")
        print("=" * 50)
        
        try:
            # Données de session CORRIGÉES selon le backend
            session_data = {
                "scenario_id": "debat_politique",  # CORRIGÉ: scenario_id au lieu de scenario_type
                "user_id": "test_user_flutter",
                "language": "fr",
                "goal": "Améliorer ma diction"
            }
            
            print(f"📤 Envoi données: {json.dumps(session_data, indent=2)}")
            
            response = requests.post(
                f"{BACKEND_CONFIG['base_url']}{BACKEND_CONFIG['session_endpoint']}",
                json=session_data,
                timeout=15
            )
            
            print(f"📥 Réponse status: {response.status_code}")
            
            if response.status_code == 201:
                session_info = response.json()
                self.session_id = session_info.get('session_id')
                
                # Extraire les infos LiveKit de la réponse
                self.livekit_token = session_info.get('livekit_token')
                self.room_name = session_info.get('room_name')
                livekit_url = session_info.get('livekit_url')
                
                print(f"✅ Session créée: {self.session_id}")
                print(f"🏠 Room LiveKit: {self.room_name}")
                print(f"🔗 URL LiveKit: {livekit_url}")
                print(f"🎫 Token LiveKit: {'PRÉSENT' if self.livekit_token else 'ABSENT'}")
                print(f"💬 Message initial: {session_info.get('initial_message', {}).get('text', 'N/A')}")
                
                return True
            else:
                print(f"❌ Erreur création session: {response.status_code}")
                print(f"📄 Réponse: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur session: {e}")
            return False
    
    async def test_livekit_connection(self):
        """Test 3: Connexion LiveKit avec les vraies données du backend"""
        print("\n🔍 TEST 3: Connexion LiveKit (avec données backend)")
        print("=" * 50)
        
        if not self.livekit_token:
            print("❌ Pas de token LiveKit du backend")
            return False
        
        if not self.room_name:
            print("❌ Pas de room_name du backend")
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
            
            # Connexion avec les vraies données
            print(f"🔗 Connexion à {LIVEKIT_CONFIG['livekit_url']}")
            print(f"🏠 Room: {self.room_name}")
            print(f"🎫 Token: {self.livekit_token[:50]}...")
            
            await asyncio.wait_for(
                self.room.connect(LIVEKIT_CONFIG['livekit_url'], self.livekit_token),
                timeout=20
            )
            
            print("✅ Connexion LiveKit réussie avec les données backend")
            return True
            
        except asyncio.TimeoutError:
            print("❌ Timeout connexion LiveKit (20s)")
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
        if "backend-agent" in participant.identity:
            print("🤖 Agent backend détecté - prêt pour l'audio!")
    
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
                if self.audio_received_count % 50 == 0:
                    frame = frame_event.frame
                    print(f"🎵 Audio reçu: {self.audio_received_count} frames de {participant.identity}")
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
    
    async def test_audio_reception_extended(self):
        """Test 4: Réception audio pendant 45 secondes"""
        print("\n🔍 TEST 4: Réception Audio Étendue (45 secondes)")
        print("=" * 50)
        
        if not self.room:
            print("❌ Pas de connexion room")
            return False
        
        print("⏳ Attente de réception audio pendant 45 secondes...")
        print("   (L'agent backend devrait se connecter et envoyer de l'audio)")
        
        start_time = time.time()
        initial_count = self.audio_received_count
        last_log_time = start_time
        
        # Attendre 45 secondes
        while time.time() - start_time < 45:
            await asyncio.sleep(1)
            
            # Log toutes les 10 secondes
            if time.time() - last_log_time >= 10:
                current_count = self.audio_received_count - initial_count
                elapsed = int(time.time() - start_time)
                print(f"⏱️ {elapsed}s: {current_count} frames audio reçus")
                last_log_time = time.time()
        
        final_count = self.audio_received_count - initial_count
        
        if final_count > 0:
            print(f"✅ Audio reçu: {final_count} frames en 45 secondes")
            return True
        else:
            print("❌ Aucun audio reçu en 45 secondes")
            return False
    
    async def test_chat_message_trigger(self):
        """Test 5: Envoyer un message chat pour déclencher l'IA"""
        print("\n🔍 TEST 5: Déclenchement IA via Message Chat")
        print("=" * 50)
        
        if not self.session_id:
            print("❌ Pas de session_id")
            return False
        
        try:
            # Envoyer message comme Flutter
            message_data = {
                "session_id": self.session_id,
                "message": "Bonjour, je voudrais améliorer ma diction pour les débats politiques",
                "message_type": "user_input"
            }
            
            print(f"📤 Envoi message: {message_data['message']}")
            
            response = requests.post(
                f"{BACKEND_CONFIG['base_url']}/chat/message",
                json=message_data,
                timeout=15
            )
            
            if response.status_code == 200:
                print("✅ Message envoyé au backend")
                print("⏳ Attente de réponse audio de l'IA...")
                
                # Attendre réponse audio
                initial_count = self.audio_received_count
                start_time = time.time()
                
                while time.time() - start_time < 20:
                    await asyncio.sleep(0.5)
                    if self.audio_received_count > initial_count:
                        new_frames = self.audio_received_count - initial_count
                        print(f"✅ Réponse audio IA reçue: {new_frames} frames")
                        return True
                
                print("❌ Pas de réponse audio IA en 20 secondes")
                return False
            else:
                print(f"❌ Erreur envoi message: {response.status_code}")
                print(f"📄 Réponse: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur test chat: {e}")
            return False
    
    async def disconnect(self):
        """Déconnexion propre"""
        if self.room:
            await self.room.disconnect()
            print("🔌 Déconnexion LiveKit")

async def main():
    """Test complet du frontend Flutter - VERSION CORRIGÉE"""
    print("🔍 DIAGNOSTIC AVANCÉ FRONTEND FLUTTER - VERSION CORRIGÉE")
    print("=" * 70)
    print("Simulation exacte du comportement de votre app Flutter")
    print("Utilise la structure backend correcte (scenario_id)")
    print("=" * 70)
    
    simulator = FlutterSimulatorFixed()
    results = {}
    
    try:
        # Test 1: Backend
        results['backend'] = await simulator.test_backend_connectivity()
        
        # Test 2: Session (structure corrigée)
        if results['backend']:
            results['session'] = await simulator.test_session_creation()
        else:
            results['session'] = False
        
        # Test 3: Connexion LiveKit (avec vraies données)
        if results['session']:
            results['connection'] = await simulator.test_livekit_connection()
            
            if results['connection']:
                # Attendre que l'agent backend se connecte
                print("\n⏳ Attente connexion agent backend (15s)...")
                await asyncio.sleep(15)
                
                # Test 4: Réception audio étendue
                results['audio_reception'] = await simulator.test_audio_reception_extended()
                
                # Test 5: Chat trigger
                results['chat_trigger'] = await simulator.test_chat_message_trigger()
            else:
                results['audio_reception'] = False
                results['chat_trigger'] = False
        else:
            results['connection'] = False
            results['audio_reception'] = False
            results['chat_trigger'] = False
        
        # Rapport final
        print("\n" + "=" * 70)
        print("📊 RAPPORT DE DIAGNOSTIC FLUTTER - VERSION CORRIGÉE")
        print("=" * 70)
        
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
        
        # Diagnostic final
        print(f"\n🔍 DIAGNOSTIC FINAL:")
        if not results['backend']:
            print("❌ PROBLÈME: Backend inaccessible")
            print("   Solution: Démarrer le backend sur localhost:8000")
        elif not results['session']:
            print("❌ PROBLÈME: Création de session échoue")
            print("   Solution: Vérifier que le scénario 'debat_politique' existe")
        elif not results['connection']:
            print("❌ PROBLÈME: Connexion LiveKit échoue")
            print("   Solution: Vérifier serveur LiveKit et token")
        elif not results['audio_reception']:
            print("❌ PROBLÈME: Aucun audio reçu de l'agent backend")
            print("   Solution: L'agent backend ne se connecte pas ou n'envoie pas d'audio")
        elif not results['chat_trigger']:
            print("⚠️ PROBLÈME: Chat ne déclenche pas l'IA")
            print("   Solution: Vérifier le pipeline chat -> IA -> TTS")
        else:
            print("✅ DIAGNOSTIC: Système complètement fonctionnel!")
            print("   Le problème est dans l'implémentation Flutter spécifique")
        
        # Recommandations
        print(f"\n💡 RECOMMANDATIONS:")
        if results['session'] and results['connection']:
            print("✅ La communication backend-LiveKit fonctionne")
            print("✅ Votre Flutter devrait pouvoir se connecter")
            print("🔍 Vérifiez dans Flutter:")
            print("   - Utilisez 'scenario_id' au lieu de 'scenario_type'")
            print("   - Vérifiez que les callbacks audio sont bien configurés")
            print("   - Testez avec les mêmes URLs que ce script")
        
    except KeyboardInterrupt:
        print("\n🛑 Test interrompu")
    except Exception as e:
        print(f"\n💥 Erreur critique: {e}")
    finally:
        await simulator.disconnect()

if __name__ == "__main__":
    asyncio.run(main())