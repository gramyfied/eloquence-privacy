#!/usr/bin/env python3
"""
Test de validation avec timestamp corrigé
"""

import jwt
import json
import time
from datetime import datetime
import requests
import websocket
import threading

# Configuration exacte du serveur LiveKit
LIVEKIT_API_KEY = "devkey"
LIVEKIT_API_SECRET = "devsecret123456789abcdef0123456789abcdef"
LIVEKIT_URL = "ws://192.168.1.44:7880"

def generate_fixed_token(room_name: str, participant_identity: str) -> str:
    """Génère un token avec timestamp corrigé (comme le backend)"""
    
    # Utiliser time.time() comme le backend corrigé
    now_timestamp = int(time.time())
    exp_timestamp = now_timestamp + (24 * 3600)  # +24 heures
    
    # Payload JWT avec structure exacte LiveKit
    payload = {
        'iss': LIVEKIT_API_KEY,  # Issuer (API Key)
        'sub': participant_identity,  # Subject (participant identity)
        'iat': now_timestamp,  # Issued at (corrigé)
        'exp': exp_timestamp,  # Expiration (corrigé)
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
    
    print(f"GENERATION TOKEN CORRIGE:")
    print(f"   API_KEY: {LIVEKIT_API_KEY}")
    print(f"   API_SECRET: {LIVEKIT_API_SECRET[:10]}...")
    print(f"   Room: {room_name}")
    print(f"   Participant: {participant_identity}")
    print(f"   IAT: {payload['iat']} ({datetime.fromtimestamp(now_timestamp)})")
    print(f"   EXP: {payload['exp']} ({datetime.fromtimestamp(exp_timestamp)})")
    print(f"   Timestamp actuel: {int(time.time())} ({datetime.now()})")
    
    # Générer le token
    token = jwt.encode(payload, LIVEKIT_API_SECRET, algorithm='HS256')
    
    print(f"TOKEN GENERE: {token[:50]}...")
    
    # Vérifier le token
    try:
        decoded = jwt.decode(token, LIVEKIT_API_SECRET, algorithms=['HS256'])
        print(f"TOKEN VALIDE - Decodage reussi")
        print(f"   Decoded IAT: {decoded['iat']} vs Now: {int(time.time())}")
        print(f"   Difference: {decoded['iat'] - int(time.time())} secondes")
    except Exception as e:
        print(f"TOKEN INVALIDE - Erreur decodage: {e}")
        
    return token

def test_backend_token():
    """Test avec un token généré par le backend"""
    print(f"\nTEST TOKEN BACKEND:")
    
    try:
        # Demander un token au backend
        response = requests.post('http://192.168.1.44:8000/api/sessions', 
                               json={
                                   'user_id': 'test-user',
                                   'scenario_id': 'test-scenario'
                               },
                               timeout=10)
        
        print(f"   Backend Status: {response.status_code}")
        
        if response.status_code == 201:
            data = response.json()
            backend_token = data.get('livekit_token')
            room_name = data.get('room_name')
            
            print(f"   Token recu du backend: {backend_token[:50]}...")
            print(f"   Room: {room_name}")
            
            # Tester ce token avec LiveKit
            return test_livekit_connection(backend_token, room_name)
        else:
            print(f"   Erreur backend: {response.text}")
            return False
            
    except Exception as e:
        print(f"   Erreur backend: {e}")
        return False

def test_livekit_connection(token: str, room_name: str) -> bool:
    """Test la connexion LiveKit avec le token"""
    print(f"\nTEST CONNEXION LIVEKIT:")
    print(f"   Room: {room_name}")
    
    success = False
    
    try:
        # Test HTTP endpoint
        url = f"http://192.168.1.44:7880/rtc/validate"
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        
        print(f"   HTTP Status: {response.status_code}")
        print(f"   HTTP Response: {response.text}")
        
        if response.status_code == 200:
            print(f"   SUCCES HTTP - Token accepte!")
            success = True
        elif response.status_code == 401:
            print(f"   ERREUR 401 - Token rejete")
        else:
            print(f"   Status inattendu: {response.status_code}")
            
    except Exception as e:
        print(f"   Erreur HTTP: {e}")
    
    return success

def main():
    print("TEST VALIDATION TOKEN CORRIGE")
    print("=" * 50)
    
    # Test 1: Token généré localement avec timestamp corrigé
    print("\n=== TEST 1: TOKEN LOCAL CORRIGE ===")
    room_name = "test-fixed-room"
    participant_identity = "test-fixed-user"
    
    token = generate_fixed_token(room_name, participant_identity)
    success1 = test_livekit_connection(token, room_name)
    
    # Test 2: Token généré par le backend corrigé
    print("\n=== TEST 2: TOKEN BACKEND CORRIGE ===")
    success2 = test_backend_token()
    
    # Résumé
    print(f"\n=== RESULTATS ===")
    print(f"Test 1 (Token local): {'SUCCES' if success1 else 'ECHEC'}")
    print(f"Test 2 (Token backend): {'SUCCES' if success2 else 'ECHEC'}")
    
    if success1 or success2:
        print(f"\nPROBLEME RESOLU! Au moins un token fonctionne.")
    else:
        print(f"\nPROBLEME PERSISTE. Investigation supplementaire necessaire.")

if __name__ == "__main__":
    main()