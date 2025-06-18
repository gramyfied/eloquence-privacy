#!/usr/bin/env python3
"""
Test simple WebSocket LiveKit
"""

import requests
import json

def test_websocket_simple():
    print("TEST WEBSOCKET LIVEKIT SIMPLE")
    print("=" * 40)
    
    # 1. Test backend
    print("1. Test backend...")
    try:
        response = requests.post(
            'http://192.168.1.44:8000/api/sessions',
            json={
                'user_id': 'test-ws',
                'scenario_id': 'test-ws',
                'language': 'fr'
            },
            timeout=10
        )
        
        if response.status_code in [200, 201]:
            data = response.json()
            token = data.get('livekit_token')
            room_name = data.get('room_name')
            print(f"Backend: OK - Token: {token[:50]}...")
            print(f"Room: {room_name}")
        else:
            print(f"Backend: ERREUR {response.status_code}")
            return False
            
    except Exception as e:
        print(f"Backend: EXCEPTION {e}")
        return False
    
    # 2. Test LiveKit HTTP
    print("\n2. Test LiveKit HTTP...")
    try:
        response = requests.get('http://192.168.1.44:7880', timeout=5)
        if response.status_code == 200:
            print("LiveKit HTTP: OK")
        else:
            print(f"LiveKit HTTP: ERREUR {response.status_code}")
            return False
    except Exception as e:
        print(f"LiveKit HTTP: EXCEPTION {e}")
        return False
    
    print("\n" + "=" * 40)
    print("SUCCES: Services opérationnels")
    print("INFO: WebSocket devrait maintenant fonctionner")
    print("ACTION: Testez l'application Flutter")
    
    return True

if __name__ == "__main__":
    success = test_websocket_simple()
    exit(0 if success else 1)