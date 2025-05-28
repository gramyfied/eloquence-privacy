import asyncio
import time
import uuid
import wave
from typing import Dict, Any, Optional, Callable
from pathlib import Path
import numpy as np

from livekit import rtc, api
from livekit.rtc import Room, RemoteParticipant, LocalParticipant, RemoteAudioTrack, DataPacketKind

from pipeline_logger import PipelineLogger, metrics_collector

class LiveKitTestClient:
    """
    Client LiveKit pour les tests de streaming audio
    Gère l'envoi et la réception de données audio
    """
    
    def __init__(self, 
                 livekit_url: str,
                 api_key: str,
                 api_secret: str,
                 client_type: str = "sender"):
        """
        Initialise le client LiveKit
        
        Args:
            livekit_url: URL du serveur LiveKit
            api_key: Clé API LiveKit
            api_secret: Secret API LiveKit
            client_type: Type de client ('sender', 'receiver', 'both')
        """
        self.livekit_url = livekit_url
        self.api_key = api_key
        self.api_secret = api_secret
        self.client_type = client_type
        
        self.logger = PipelineLogger(f"LIVEKIT_{client_type.upper()}")
        metrics_collector.register_logger(self.logger)
        
        self.room: Optional[Room] = None
        self.participant_identity = f"test_{client_type}_{uuid.uuid4().hex[:8]}"
        self.room_name = None
        
        # Callbacks pour les événements
        self.on_audio_received: Optional[Callable] = None
        self.on_data_received: Optional[Callable] = None
        self.on_participant_connected: Optional[Callable] = None
        self.on_participant_disconnected: Optional[Callable] = None
        
        # Statistiques
        self.connection_start_time = None
        self.last_packet_time = None
        self.packet_counter = 0
        
        self.logger.info(f"🤖 Client LiveKit initialisé: {client_type}")
        self.logger.debug(f"🆔 Identity: {self.participant_identity}")
    
    async def connect(self, room_name: str, participant_name: Optional[str] = None) -> bool:
        """
        Se connecte à une room LiveKit
        
        Args:
            room_name: Nom de la room
            participant_name: Nom du participant (optionnel)
        
        Returns:
            True si la connexion réussit, False sinon
        """
        self.room_name = room_name
        connection_start = time.time()
        
        self.logger.connection_event("connecting", f"Room: {room_name}")
        
        try:
            # Créer la room
            self.room = Room()
            
            # Configurer les event handlers
            self._setup_event_handlers()
            
            # Générer le token d'accès
            token = self._generate_access_token(room_name, participant_name)
            
            self.logger.debug(f"🎫 Token généré: {token[:50]}...")
            
            # Options de connexion
            options = rtc.RoomOptions(
                auto_subscribe=True,
                dynacast=True,
                adaptive_stream=True,
            )
            
            # Tentative de connexion
            await self.room.connect(self.livekit_url, token, options=options)
            
            connection_time = (time.time() - connection_start) * 1000
            self.connection_start_time = time.time()
            
            self.logger.connection_event("connected", f"Room: {room_name}")
            self.logger.latency("connexion", connection_time)
            self.logger.success(f"Connecté en tant que: {self.participant_identity}")
            
            return True
            
        except Exception as e:
            connection_time = (time.time() - connection_start) * 1000
            self.logger.connection_event("failed", f"Erreur: {str(e)}")
            self.logger.latency("connexion_échec", connection_time)
            self.logger.error(f"💥 Erreur de connexion: {e}")
            return False
    
    def _generate_access_token(self, room_name: str, participant_name: Optional[str] = None) -> str:
        """Génère un token d'accès LiveKit"""
        token_builder = api.AccessToken(self.api_key, self.api_secret)
        
        video_grants = api.VideoGrants(
            room_join=True,
            room=room_name,
            can_publish=True,
            can_subscribe=True,
            can_publish_data=True
        )
        
        token = token_builder.with_identity(self.participant_identity) \
                            .with_name(participant_name or self.participant_identity) \
                            .with_grants(video_grants) \
                            .to_jwt()
        
        return token
    
    def _setup_event_handlers(self):
        """Configure les gestionnaires d'événements LiveKit"""
        
        @self.room.on("participant_connected")
        def on_participant_connected(participant: RemoteParticipant):
            self.logger.connection_event("participant_joined", f"Identity: {participant.identity}")
            if self.on_participant_connected:
                asyncio.create_task(self.on_participant_connected(participant))
        
        @self.room.on("participant_disconnected")
        def on_participant_disconnected(participant: RemoteParticipant):
            self.logger.connection_event("participant_left", f"Identity: {participant.identity}")
            if self.on_participant_disconnected:
                asyncio.create_task(self.on_participant_disconnected(participant))
        
        @self.room.on("track_subscribed")
        def on_track_subscribed(track, publication, participant: RemoteParticipant):
            self.logger.info(f"🎵 Track souscrite: {track.sid} de {participant.identity}")
            if isinstance(track, RemoteAudioTrack):
                self.logger.success(f"Audio track reçue de {participant.identity}")
                asyncio.create_task(self._handle_audio_track(track, participant))
        
        @self.room.on("data_received")
        def on_data_received(data_packet):
            self.logger.debug(f"📦 Données reçues: {len(data_packet.data)} bytes")
            self.logger.audio_received(
                self.packet_counter,
                len(data_packet.data),
                time.time(),
                {"participant": data_packet.participant.identity if data_packet.participant else "unknown"}
            )
            
            if self.on_data_received:
                asyncio.create_task(self.on_data_received(data_packet))
        
        @self.room.on("disconnected")
        def on_disconnected():
            self.logger.connection_event("disconnected", "Room fermée")
        
        @self.room.on("reconnecting")
        def on_reconnecting():
            self.logger.connection_event("reconnecting", "Tentative de reconnexion")
        
        @self.room.on("reconnected")
        def on_reconnected():
            self.logger.connection_event("reconnected", "Reconnexion réussie")
    
    async def _handle_audio_track(self, track: RemoteAudioTrack, participant: RemoteParticipant):
        """Gère la réception d'une piste audio"""
        self.logger.info(f"🎧 Démarrage lecture audio de {participant.identity}")
        
        try:
            async for audio_frame in track.audio_stream:
                if self.on_audio_received:
                    # Convertir l'AudioFrame en bytes
                    audio_data = audio_frame.samples.tobytes()
                    
                    self.logger.audio_received(
                        self.packet_counter,
                        len(audio_data),
                        time.time(),
                        {
                            "participant": participant.identity,
                            "sample_rate": audio_frame.sample_rate,
                            "channels": audio_frame.num_channels
                        }
                    )
                    
                    await self.on_audio_received(audio_data, participant.identity, audio_frame)
                    self.packet_counter += 1
                    
        except Exception as e:
            self.logger.error(f"💥 Erreur lecture audio de {participant.identity}: {e}")
    
    async def send_audio_file(self, audio_file_path: Path, metadata: Optional[Dict] = None) -> bool:
        """
        Envoie un fichier audio via LiveKit
        
        Args:
            audio_file_path: Chemin vers le fichier audio
            metadata: Métadonnées optionnelles
        
        Returns:
            True si l'envoi réussit, False sinon
        """
        if not self.room or not self.room.isconnected:
            self.logger.error("❌ Pas de connexion LiveKit active")
            return False
        
        send_start = time.time()
        
        try:
            # Lire le fichier audio
            with wave.open(str(audio_file_path), 'rb') as wav_file:
                audio_data = wav_file.readframes(wav_file.getnframes())
                sample_rate = wav_file.getframerate()
                channels = wav_file.getnchannels()
            
            file_size = len(audio_data)
            self.packet_counter += 1
            
            self.logger.debug(f"📤 Envoi fichier audio: {audio_file_path.name}")
            self.logger.debug(f"📊 Taille: {file_size} bytes, {sample_rate}Hz, {channels}ch")
            
            # Envoyer via data channel pour ce test
            # Dans un vrai système, on utiliserait les audio tracks
            packet_data = {
                "type": "audio_file",
                "filename": audio_file_path.name,
                "size": file_size,
                "sample_rate": sample_rate,
                "channels": channels,
                "metadata": metadata or {},
                "timestamp": time.time(),
                "packet_id": self.packet_counter
            }
            
            # Convertir en bytes pour l'envoi
            import json
            header = json.dumps(packet_data).encode('utf-8')
            header_size = len(header).to_bytes(4, byteorder='big')
            
            # Envoyer header + données audio
            full_packet = header_size + header + audio_data
            
            await self.room.local_participant.publish_data(
                full_packet, 
                DataPacketKind.KIND_RELIABLE
            )
            
            send_time = (time.time() - send_start) * 1000
            self.last_packet_time = time.time()
            
            self.logger.audio_packet(
                self.packet_counter,
                len(full_packet),
                time.time(),
                metadata
            )
            
            self.logger.latency("envoi", send_time)
            self.logger.success(f"Audio envoyé: {audio_file_path.name}")
            
            return True
            
        except Exception as e:
            send_time = (time.time() - send_start) * 1000
            self.logger.latency("envoi_échec", send_time)
            self.logger.error(f"💥 Erreur envoi audio: {e}")
            return False
    
    async def send_raw_data(self, data: bytes, data_type: str = "raw", metadata: Optional[Dict] = None) -> bool:
        """
        Envoie des données brutes via LiveKit
        
        Args:
            data: Données à envoyer
            data_type: Type de données
            metadata: Métadonnées optionnelles
        
        Returns:
            True si l'envoi réussit, False sinon
        """
        if not self.room or not self.room.isconnected:
            self.logger.error("❌ Pas de connexion LiveKit active")
            return False
        
        send_start = time.time()
        
        try:
            self.packet_counter += 1
            
            # Préparer le paquet
            packet_info = {
                "type": data_type,
                "size": len(data),
                "timestamp": time.time(),
                "packet_id": self.packet_counter,
                "metadata": metadata or {}
            }
            
            import json
            header = json.dumps(packet_info).encode('utf-8')
            header_size = len(header).to_bytes(4, byteorder='big')
            
            full_packet = header_size + header + data
            
            await self.room.local_participant.publish_data(
                full_packet,
                DataPacketKind.KIND_RELIABLE
            )
            
            send_time = (time.time() - send_start) * 1000
            
            self.logger.audio_packet(
                self.packet_counter,
                len(full_packet),
                time.time(),
                metadata
            )
            
            self.logger.latency("envoi_raw", send_time)
            
            return True
            
        except Exception as e:
            send_time = (time.time() - send_start) * 1000
            self.logger.latency("envoi_raw_échec", send_time)
            self.logger.error(f"💥 Erreur envoi données: {e}")
            return False
    
    async def simulate_network_conditions(self, 
                                        packet_loss_rate: float = 0.0,
                                        latency_ms: float = 0.0,
                                        jitter_ms: float = 0.0):
        """
        Simule des conditions réseau dégradées
        
        Args:
            packet_loss_rate: Taux de perte de paquets (0.0 à 1.0)
            latency_ms: Latence supplémentaire en ms
            jitter_ms: Variation de latence en ms
        """
        if packet_loss_rate > 0:
            self.logger.network_event("packet_loss_simulation", f"{packet_loss_rate:.1%}")
        
        if latency_ms > 0:
            self.logger.network_event("latency_simulation", f"{latency_ms}ms")
            await asyncio.sleep(latency_ms / 1000)
        
        if jitter_ms > 0:
            jitter = np.random.uniform(-jitter_ms, jitter_ms) / 1000
            if jitter > 0:
                await asyncio.sleep(jitter)
    
    async def disconnect(self):
        """Se déconnecte de la room LiveKit"""
        if self.room and self.room.isconnected:
            self.logger.connection_event("disconnecting", f"Room: {self.room_name}")
            
            try:
                await self.room.disconnect()
                self.logger.connection_event("disconnected", "Déconnexion réussie")
                
                # Calculer les statistiques de session
                if self.connection_start_time:
                    session_duration = time.time() - self.connection_start_time
                    self.logger.performance_metric("session_duration", session_duration, "seconds")
                
            except Exception as e:
                self.logger.error(f"💥 Erreur lors de la déconnexion: {e}")
        
        self.room = None
    
    def get_connection_stats(self) -> Dict[str, Any]:
        """Retourne les statistiques de connexion"""
        stats = {
            "is_connected": self.room.isconnected if self.room else False,
            "participant_identity": self.participant_identity,
            "room_name": self.room_name,
            "packets_sent": self.packet_counter,
            "connection_start_time": self.connection_start_time,
            "last_packet_time": self.last_packet_time
        }
        
        if self.room and self.room.isconnected:
            stats.update({
                "local_participant": self.room.local_participant.identity if self.room.local_participant else None,
                "remote_participants": [p.identity for p in self.room.remote_participants.values()],
                "remote_participants_count": len(self.room.remote_participants)
            })
        
        return stats
    
    @property
    def is_connected(self) -> bool:
        """Vérifie si le client est connecté"""
        return self.room is not None and self.room.isconnected
    
    def __del__(self):
        """Nettoyage lors de la destruction"""
        if hasattr(self, 'room') and self.room:
            try:
                asyncio.create_task(self.disconnect())
            except:
                pass