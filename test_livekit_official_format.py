#!/usr/bin/env python3
"""
Test avec format JWT officiel LiveKit
Basé sur la documentation officielle LiveKit
"""

import jwt
import json
import time
from datetime import datetime
import requests

# Configuration exacte du serveur LiveKit
LIVEKIT_API_KEY = "devkey"
LIVEKIT_API_SECRET = "devsecret123456789abcdef0123456789abcdef"

def generate_official_livekit_token(room_name: str, participant_identity: str) -> str:
    """Génère un token avec le format EXACT de LiveKit officiel"""
    
    now_timestamp = int(time.time())
    exp_timestamp = now_timestamp + (24 * 3600)
    
    # Format EXACT selon la documentation LiveKit officielle
    payload = {
        'iss': LIVEKIT_API_KEY,
        'sub': participant_identity,
        'iat': now_timestamp,
        'exp': exp_timestamp,
        'nbf': now_timestamp,  # Not Before - AJOUT CRITIQUE
        'video': {  # STRUCTURE OFFICIELLE - pas "grants"
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
    
    print(f"GENERATION TOKEN FORMAT OFFICIEL:")
    print(f"   Structure: 'video' au lieu de 'grants'")
    print(f"   NBF ajoute: {payload['nbf']}")
    print(f"   IAT: {payload['iat']}")
    print(f"   EXP: {payload['exp']}")
    
    token = jwt.encode(payload, LIVEKIT_API_SECRET, algorithm='HS256')
    print(f"   Token: {token[:50]}...")
    
    return token

def generate_minimal_token(room_name: str, participant_identity: str) -> str:
    """Génère un token minimal pour test"""
    
    now_timestamp = int(time.time())
    exp_timestamp = now_timestamp + (24 * 3600)
    
    # Token MINIMAL
    payload = {
        'iss': LIVEKIT_API_KEY,
        'sub': participant_identity,
        'iat': now_timestamp,
        'exp': exp_timestamp,
        'video': {
            'roomJoin': True,
            'room': room_name
        }
    }
    
    print(f"GENERATION TOKEN MINIMAL:")
    print(f"   Seulement roomJoin et room")
    
    token = jwt.encode(payload, LIVEKIT_API_SECRET, algorithm='HS256')
    print(f"   Token: {token[:50]}...")
    
    return token

def generate_alternative_format(room_name: str, participant_identity: str) -> str:
    """Test format alternatif sans 'video'"""
    
    now_timestamp = int(time.time())
    exp_timestamp = now_timestamp + (24 * 3600)
    
    # Format SANS video wrapper
    payload = {
        'iss': LIVEKIT_API_KEY,
        'sub': participant_identity,
        'iat': now_timestamp,
        'exp': exp_timestamp,
        'room': room_name,
        'roomJoin': True,
        'canPublish': True,
        'canSubscribe': True
    }
    
    print(f"GENERATION TOKEN ALTERNATIF:")
    print(f"   Permissions directes sans wrapper")
    
    token = jwt.encode(payload, LIVEKIT_API_SECRET, algorithm='HS256')
    print(f"   Token: {token[:50]}...")
    
    return token

def test_token(token: str, room_name: str, test_name: str) -> bool:
    """Test un token avec LiveKit"""
    print(f"\nTEST {test_name}:")
    
    try:
        url = f"http://192.168.1.44:7880/rtc/validate"
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.text}")
        
        if response.status_code == 200:
            print(f"   SUCCES!")
            return True
        else:
            print(f"   ECHEC")
            return False
            
    except Exception as e:
        print(f"   Erreur: {e}")
        return False

def main():
    print("TEST FORMATS JWT LIVEKIT OFFICIELS")
    print("=" * 50)
    
    room_name = "test-official-room"
    participant_identity = "test-official-user"
    
    # Test 1: Format officiel avec 'video'
    print("\n=== TEST 1: FORMAT OFFICIEL (video) ===")
    token1 = generate_official_livekit_token(room_name, participant_identity)
    success1 = test_token(token1, room_name, "FORMAT OFFICIEL")
    
    # Test 2: Format minimal
    print("\n=== TEST 2: FORMAT MINIMAL ===")
    token2 = generate_minimal_token(room_name, participant_identity)
    success2 = test_token(token2, room_name, "FORMAT MINIMAL")
    
    # Test 3: Format alternatif
    print("\n=== TEST 3: FORMAT ALTERNATIF ===")
    token3 = generate_alternative_format(room_name, participant_identity)
    success3 = test_token(token3, room_name, "FORMAT ALTERNATIF")
    
    # Résumé
    print(f"\n=== RESULTATS FINAUX ===")
    print(f"Test 1 (Format officiel): {'SUCCES' if success1 else 'ECHEC'}")
    print(f"Test 2 (Format minimal): {'SUCCES' if success2 else 'ECHEC'}")
    print(f"Test 3 (Format alternatif): {'SUCCES' if success3 else 'ECHEC'}")
    
    if success1 or success2 or success3:
        print(f"\nPROBLEME RESOLU! Format fonctionnel trouve.")
        if success1:
            print("-> Utiliser le format officiel avec 'video'")
        elif success2:
            print("-> Utiliser le format minimal")
        elif success3:
            print("-> Utiliser le format alternatif")
    else:
        print(f"\nTOUS LES FORMATS ECHOUENT. Probleme plus profond.")

if __name__ == "__main__":
    main()