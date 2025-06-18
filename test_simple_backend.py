#!/usr/bin/env python3
"""
Test simple backend et LiveKit
"""

import requests
import json

def test_backend():
    print("TEST BACKEND SIMPLE")
    print("=" * 30)
    
    try:
        response = requests.post(
            'http://192.168.1.44:8000/api/sessions',
            json={
                'user_id': 'test-final',
                'scenario_id': 'test-final',
                'language': 'fr'
            },
            timeout=10
        )
        
        print(f"Status: {response.status_code}")
        
        if response.status_code in [200, 201]:
            data = response.json()
            print("Backend: OK")
            print(f"Token: {data.get('livekit_token', '')[:50]}...")
            print(f"Room: {data.get('room_name', '')}")
            return True
        else:
            print(f"Backend: Erreur {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"Backend: Exception {e}")
        return False

def test_livekit():
    print("\nTEST LIVEKIT HTTP")
    print("=" * 30)
    
    try:
        response = requests.get('http://192.168.1.44:7880', timeout=5)
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            print("LiveKit: OK")
            return True
        else:
            print(f"LiveKit: Erreur {response.status_code}")
            return False
    except Exception as e:
        print(f"LiveKit: Exception {e}")
        return False

if __name__ == "__main__":
    backend_ok = test_backend()
    livekit_ok = test_livekit()
    
    print("\n" + "=" * 30)
    if backend_ok and livekit_ok:
        print("SUCCES: Tous les tests passent!")
        print("Pret pour test Flutter")
    else:
        print("ECHEC: Certains tests ont echoue")
    
    exit(0 if (backend_ok and livekit_ok) else 1)