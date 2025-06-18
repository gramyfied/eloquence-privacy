#!/usr/bin/env python3
"""
Script de test pour diagnostiquer le problème JWT LiveKit
Génère un token avec les clés exactes du serveur et teste la connexion
"""

import jwt
import json
from datetime import datetime, timedelta
import requests
import websocket
import threading
import time

# Configuration exacte du serveur LiveKit
LIVEKIT_API_KEY = "devkey"
LIVEKIT_API_SECRET = "devsecret123456789abcdef0123456789abcdef"
LIVEKIT_URL = "ws://192.168.1.44:7880"

def generate_test_token(room_name: str, participant_identity: str) -> str:
    """Génère un token de test avec les clés exactes du serveur"""
    
    now = datetime.utcnow()
    exp = now + timedelta(hours=24)
    
    # Payload JWT avec structure exacte LiveKit
    payload = {
        'iss': LIVEKIT_API_KEY,  # Issuer (API Key)
        'sub': participant_identity,  # Subject (participant identity)
        'iat': int(now.timestamp()),  # Issued at
        'exp': int(exp.timestamp()),  # Expiration
        'room': room_name,  # Room name
        'grants': {
            'room': room_name,
            'roomJoin': True,
            'roomList': True,
            'roomRecord': False,
            'roomAdmin': False,
            'roomCreate': False,
            'canPublish': True,
            'canSubscribe': True,
            'canPublishData': True,
            'canUpdateOwnMetadata': True
        }
    }
    
    print(f"GENERATION TOKEN:")
    print(f"   API_KEY: {LIVEKIT_API_KEY}")
    print(f"   API_SECRET: {LIVEKIT_API_SECRET[:10]}...")
    print(f"   Room: {room_name}")
    print(f"   Participant: {participant_identity}")
    print(f"   IAT: {payload['iat']} ({now})")
    print(f"   EXP: {payload['exp']} ({exp})")
    print(f"   Grants: {json.dumps(payload['grants'], indent=2)}")
    
    # Générer le token
    token = jwt.encode(payload, LIVEKIT_API_SECRET, algorithm='HS256')
    
    print(f"TOKEN GENERE: {token[:50]}...")
    
    # Vérifier le token
    try:
        decoded = jwt.decode(token, LIVEKIT_API_SECRET, algorithms=['HS256'])
        print(f"TOKEN VALIDE - Decodage reussi")
        print(f"   Decoded payload: {json.dumps(decoded, indent=2)}")
    except Exception as e:
        print(f"TOKEN INVALIDE - Erreur decodage: {e}")
        
    return token

def test_http_endpoint(token: str, room_name: str):
    """Test l'endpoint HTTP LiveKit"""
    print(f"\nTEST HTTP ENDPOINT:")
    
    try:
        # Test endpoint /rtc/validate
        url = f"http://192.168.1.44:7880/rtc/validate"
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        print(f"   URL: {url}")
        print(f"   Headers: {headers}")
        
        response = requests.get(url, headers=headers, timeout=10)
        
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text}")
        
        if response.status_code == 401:
            print(f"ERREUR 401 CONFIRMEE sur endpoint HTTP")
        elif response.status_code == 200:
            print(f"SUCCES HTTP - Token accepte")
        else:
            print(f"Status inattendu: {response.status_code}")
            
    except Exception as e:
        print(f"ERREUR HTTP: {e}")

def test_websocket_connection(token: str, room_name: str):
    """Test la connexion WebSocket LiveKit"""
    print(f"\nTEST WEBSOCKET:")
    
    try:
        ws_url = f"ws://192.168.1.44:7880/rtc?access_token={token}"
        print(f"   URL: {ws_url}")
        
        def on_message(ws, message):
            print(f"WS Message: {message}")
            
        def on_error(ws, error):
            print(f"WS Error: {error}")
            
        def on_close(ws, close_status_code, close_msg):
            print(f"WS Closed: {close_status_code} - {close_msg}")
            
        def on_open(ws):
            print(f"WS Connected successfully!")
            # Fermer après 2 secondes
            threading.Timer(2.0, ws.close).start()
        
        ws = websocket.WebSocketApp(ws_url,
                                  on_open=on_open,
                                  on_message=on_message,
                                  on_error=on_error,
                                  on_close=on_close)
        
        ws.run_forever(ping_interval=30, ping_timeout=10)
        
    except Exception as e:
        print(f"ERREUR WEBSOCKET: {e}")

def main():
    print("DIAGNOSTIC TOKEN JWT LIVEKIT")
    print("=" * 50)
    
    # Paramètres de test
    room_name = "test-diagnostic-room"
    participant_identity = "diagnostic-user"
    
    # Générer token de test
    token = generate_test_token(room_name, participant_identity)
    
    # Test HTTP
    test_http_endpoint(token, room_name)
    
    # Test WebSocket
    test_websocket_connection(token, room_name)
    
    print("\nDIAGNOSTIC TERMINE")

if __name__ == "__main__":
    main()