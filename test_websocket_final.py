#!/usr/bin/env python3
"""
Test final WebSocket LiveKit après résolution STUN
"""

import requests
import json
import websocket
import threading
import time

def test_websocket_connection():
    print("TEST WEBSOCKET LIVEKIT FINAL")
    print("=" * 40)
    
    # 1. Obtenir un token du backend
    print("1. Génération token...")
    try:
        response = requests.post(
            'http://192.168.1.44:8000/api/sessions',
            json={
                'user_id': 'test-websocket',
                'scenario_id': 'test-websocket',
                'language': 'fr'
            },
            timeout=10
        )
        
        if response.status_code in [200, 201]:
            data = response.json()
            token = data.get('livekit_token')
            room_name = data.get('room_name')
            print(f"✅ Token généré: {token[:50]}...")
            print(f"✅ Room: {room_name}")
        else:
            print(f"❌ Erreur backend: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Exception backend: {e}")
        return False
    
    # 2. Test connexion WebSocket
    print("\n2. Test connexion WebSocket...")
    
    ws_url = f"ws://192.168.1.44:7880/rtc?access_token={token}"
    
    connection_success = False
    error_message = None
    
    def on_message(ws, message):
        print(f"📨 Message reçu: {message[:100]}...")
    
    def on_error(ws, error):
        nonlocal error_message
        error_message = str(error)
        print(f"❌ Erreur WebSocket: {error}")
    
    def on_close(ws, close_status_code, close_msg):
        print(f"🔌 WebSocket fermé: {close_status_code} - {close_msg}")
    
    def on_open(ws):
        nonlocal connection_success
        connection_success = True
        print("✅ WebSocket connecté!")
        # Fermer après connexion réussie
        time.sleep(1)
        ws.close()
    
    try:
        print(f"🔗 Connexion à: {ws_url[:50]}...")
        ws = websocket.WebSocketApp(
            ws_url,
            on_open=on_open,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close
        )
        
        # Lancer la connexion dans un thread
        wst = threading.Thread(target=ws.run_forever)
        wst.daemon = True
        wst.start()
        
        # Attendre 5 secondes pour la connexion
        wst.join(timeout=5)
        
        if connection_success:
            print("✅ Test WebSocket: SUCCÈS")
            return True
        else:
            print(f"❌ Test WebSocket: ÉCHEC - {error_message}")
            return False
            
    except Exception as e:
        print(f"❌ Exception WebSocket: {e}")
        return False

if __name__ == "__main__":
    print("Installation websocket-client si nécessaire...")
    try:
        import websocket
    except ImportError:
        print("Installation de websocket-client...")
        import subprocess
        subprocess.check_call(["pip", "install", "websocket-client"])
        import websocket
    
    success = test_websocket_connection()
    
    print("\n" + "=" * 40)
    if success:
        print("🎉 SUCCÈS COMPLET!")
        print("✅ Backend opérationnel")
        print("✅ LiveKit accessible")
        print("✅ WebSocket fonctionnel")
        print("🚀 L'audio devrait maintenant fonctionner dans Flutter!")
    else:
        print("❌ ÉCHEC - Problèmes persistants")
        print("📋 Vérifiez les logs LiveKit pour plus de détails")
    
    exit(0 if success else 1)