#!/usr/bin/env python3
"""
Test simple final
"""

import requests
import time

def test_simple():
    print("TEST SIMPLE FINAL")
    print("=" * 30)
    
    # Attendre que le backend soit prêt
    print("Attente backend...")
    time.sleep(5)
    
    try:
        # Test simple
        response = requests.post('http://192.168.1.44:8000/api/sessions', 
                               json={
                                   'user_id': 'test-simple',
                                   'scenario_id': 'test-simple'
                               },
                               timeout=15)
        
        print(f"Backend Status: {response.status_code}")
        
        if response.status_code == 201:
            data = response.json()
            token = data.get('livekit_token')
            
            print(f"Token recu: {token[:50]}...")
            
            # Test HTTP validation
            url = f"http://192.168.1.44:7880/rtc/validate"
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            print(f"LiveKit Status: {response.status_code}")
            print(f"LiveKit Response: {response.text}")
            
            if response.status_code == 200:
                print("SUCCES! Probleme resolu!")
                return True
            else:
                print("Echec. Probleme persiste.")
                return False
        else:
            print(f"Erreur backend: {response.text}")
            return False
            
    except Exception as e:
        print(f"Erreur: {e}")
        return False

if __name__ == "__main__":
    test_simple()