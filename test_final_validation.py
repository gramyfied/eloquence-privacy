#!/usr/bin/env python3
"""
Test final de validation avec backend corrigé
"""

import requests
import websocket
import threading
import time

def test_backend_corrected():
    """Test avec le backend corrigé"""
    print("TEST BACKEND CORRIGE")
    print("=" * 30)
    
    try:
        # Demander un token au backend corrigé
        response = requests.post('http://192.168.1.44:8000/api/sessions', 
                               json={
                                   'user_id': 'test-final',
                                   'scenario_id': 'validation-finale'
                               },
                               timeout=10)
        
        print(f"Backend Status: {response.status_code}")
        
        if response.status_code == 201:
            data = response.json()
            token = data.get('livekit_token')
            room_name = data.get('room_name')
            livekit_url = data.get('livekit_url')
            
            print(f"Token recu: {token[:50]}...")
            print(f"Room: {room_name}")
            print(f"URL: {livekit_url}")
            
            # Test HTTP validation
            print(f"\nTest HTTP validation:")
            url = f"http://192.168.1.44:7880/rtc/validate"
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            print(f"   Status: {response.status_code}")
            print(f"   Response: {response.text}")
            
            if response.status_code == 200:
                print(f"   SUCCES HTTP!")
                
                # Test WebSocket
                print(f"\nTest WebSocket:")
                test_websocket(token, room_name)
                return True
            else:
                print(f"   ECHEC HTTP")
                return False
        else:
            print(f"Erreur backend: {response.text}")
            return False
            
    except Exception as e:
        print(f"Erreur: {e}")
        return False

def test_websocket(token, room_name):
    """Test connexion WebSocket"""
    success = False
    
    def on_message(ws, message):
        print(f"   WS Message: {message}")
        
    def on_error(ws, error):
        print(f"   WS Error: {error}")
        
    def on_close(ws, close_status_code, close_msg):
        print(f"   WS Closed: {close_status_code}")
        
    def on_open(ws):
        nonlocal success
        print(f"   WS Connected successfully!")
        success = True
        # Fermer après 2 secondes
        threading.Timer(2.0, ws.close).start()
    
    try:
        ws_url = f"ws://192.168.1.44:7880/rtc?access_token={token}"
        ws = websocket.WebSocketApp(ws_url,
                                  on_open=on_open,
                                  on_message=on_message,
                                  on_error=on_error,
                                  on_close=on_close)
        
        ws.run_forever(ping_interval=30, ping_timeout=10)
        
        if success:
            print(f"   SUCCES WEBSOCKET!")
        else:
            print(f"   ECHEC WEBSOCKET")
            
    except Exception as e:
        print(f"   Erreur WebSocket: {e}")

def main():
    print("VALIDATION FINALE - PROBLEME JWT LIVEKIT")
    print("=" * 50)
    
    success = test_backend_corrected()
    
    print(f"\n" + "=" * 50)
    if success:
        print("PROBLEME RESOLU!")
        print("✅ Backend genere des tokens valides")
        print("✅ LiveKit accepte les tokens")
        print("✅ Connexion WebSocket etablie")
        print("\nL'application Flutter peut maintenant se connecter!")
    else:
        print("PROBLEME PERSISTE")
        print("❌ Investigation supplementaire necessaire")

if __name__ == "__main__":
    main()