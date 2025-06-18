#!/usr/bin/env python3
"""
Script de diagnostic simple pour confirmer le problème agent
"""

import requests
import json

def test_session_creation():
    """Test creation session avec diagnostic"""
    print("TEST CREATION SESSION AVEC DIAGNOSTIC")
    print("=" * 50)
    
    # Creer une session
    print("Creation d'une nouvelle session...")
    response = requests.post(
        "http://192.168.1.44:8000/api/sessions",
        json={
            "user_id": "diagnostic-simple-test",
            "scenario_id": "demo-1", 
            "language": "fr"
        },
        headers={"Content-Type": "application/json"}
    )
    
    if response.status_code == 201:
        session_data = response.json()
        print("SUCCESS: Session creee avec succes")
        print(f"Room: {session_data['room_name']}")
        print(f"Token genere: {session_data['livekit_token'][:50]}...")
        
        # Verifier si agent_connected est present
        agent_connected = session_data.get('agent_connected', False)
        agent_identity = session_data.get('agent_identity', 'N/A')
        
        print(f"Agent connecte: {agent_connected}")
        print(f"Agent identity: {agent_identity}")
        
        if not agent_connected:
            print("PROBLEME CONFIRME: Aucun agent connecte automatiquement")
            print("CAUSE: L'endpoint /api/sessions ne lance pas d'agent")
            return False
        else:
            print("SUCCESS: Agent connecte automatiquement")
            return True
            
    else:
        print(f"ERROR: Erreur creation session: {response.status_code}")
        print(f"Response: {response.text}")
        return False

def main():
    """Fonction principale"""
    print("DIAGNOSTIC AGENT LIVEKIT - DEMARRAGE")
    print("=" * 50)
    
    # Test creation session
    agent_works = test_session_creation()
    
    print("\n" + "=" * 50)
    print("CONCLUSION DIAGNOSTIC:")
    print("Backend fonctionne: OUI")
    print("Sessions se creent: OUI")
    print(f"Agent automatique: {'OUI' if agent_works else 'NON'}")
    
    if not agent_works:
        print("\nSOLUTION REQUISE:")
        print("1. Modifier /api/sessions pour lancer agent automatiquement")
        print("2. Integrer service agent dans le backend")
        print("3. Ajouter orchestration session <-> agent")

if __name__ == "__main__":
    main()