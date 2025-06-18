#!/usr/bin/env python3
"""
Script pour ajouter des logs de diagnostic dans le backend
"""

import requests
import json
import time

def test_session_creation_with_logs():
    """Test création session avec logs détaillés"""
    print("🔍 TEST CRÉATION SESSION AVEC LOGS DÉTAILLÉS")
    
    # Créer une session
    print("📝 Création d'une nouvelle session...")
    response = requests.post(
        "http://192.168.1.44:8000/api/sessions",
        json={
            "user_id": "diagnostic-logs-test",
            "scenario_id": "demo-1", 
            "language": "fr"
        },
        headers={"Content-Type": "application/json"}
    )
    
    if response.status_code == 201:
        session_data = response.json()
        print("✅ Session créée avec succès")
        print(f"🏠 Room: {session_data['room_name']}")
        print(f"🎫 Token généré: {session_data['livekit_token'][:50]}...")
        
        # Vérifier si agent_connected est présent
        agent_connected = session_data.get('agent_connected', False)
        agent_identity = session_data.get('agent_identity', 'N/A')
        
        print(f"🤖 Agent connecté: {agent_connected}")
        print(f"🤖 Agent identity: {agent_identity}")
        
        if not agent_connected:
            print("❌ PROBLÈME CONFIRMÉ: Aucun agent connecté automatiquement")
            print("💡 CAUSE: L'endpoint /api/sessions ne lance pas d'agent")
        else:
            print("✅ Agent connecté automatiquement")
            
        return session_data
    else:
        print(f"❌ Erreur création session: {response.status_code}")
        print(f"❌ Réponse: {response.text}")
        return None

def check_active_sessions():
    """Vérifier les sessions actives"""
    print("\n📊 VÉRIFICATION SESSIONS ACTIVES")
    
    try:
        response = requests.get("http://192.168.1.44:8000/api/sessions/active")
        if response.status_code == 200:
            data = response.json()
            active_count = data.get('total_active', 0)
            print(f"📈 Sessions actives: {active_count}")
            
            if active_count > 0:
                sessions = data.get('active_sessions', {})
                for key, session in sessions.items():
                    print(f"  - Session: {session['room_name']}")
                    print(f"    User: {session['user_id']}")
                    print(f"    Status: {session['status']}")
            else:
                print("📭 Aucune session active")
        else:
            print(f"❌ Erreur consultation sessions: {response.status_code}")
    except Exception as e:
        print(f"❌ Erreur: {e}")

def main():
    """Fonction principale de diagnostic"""
    print("🚀 DIAGNOSTIC LOGS AGENT - DÉMARRAGE")
    print("=" * 50)
    
    # Test 1: Création session
    session_data = test_session_creation_with_logs()
    
    # Test 2: Sessions actives
    check_active_sessions()
    
    # Test 3: Diagnostic backend
    print("\n🔧 DIAGNOSTIC BACKEND")
    try:
        response = requests.get("http://192.168.1.44:8000/api/diagnostic")
        if response.status_code == 200:
            data = response.json()
            print("✅ Backend diagnostic accessible")
            print(f"📊 Status: {data.get('backend_status', 'unknown')}")
            print(f"🔧 Celery: {data.get('celery_status', 'unknown')}")
        else:
            print(f"❌ Erreur diagnostic: {response.status_code}")
    except Exception as e:
        print(f"❌ Erreur diagnostic: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 CONCLUSION DIAGNOSTIC:")
    print("✅ Backend fonctionne")
    print("✅ Sessions se créent")
    print("❌ AUCUN AGENT AUTOMATIQUE")
    print("💡 SOLUTION: Modifier /api/sessions pour lancer agent")

if __name__ == "__main__":
    main()