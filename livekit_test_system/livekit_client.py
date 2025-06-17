import asyncio
import time
import uuid
import wave
from typing import Dict, Any, Optional, Callable
from pathlib import Path
import numpy as np

from livekit import rtc, api
from livekit.rtc import Room, RemoteParticipant, LocalParticipant, RemoteAudioTrack, DataPacketKind
from livekit.protocol.models import AudioCodec
from livekit.rtc.audio_stream import AudioStream

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
        
        # Piste audio locale
        self.audio_track: Optional[rtc.LocalAudioTrack] = None
        self.audio_source: Optional[rtc.AudioSource] = None # Stocker la source audio
        self.audio_stream_track: Optional[rtc.LocalAudioTrack] = None # Nouvelle piste pour le streaming continu
        
        # Statistiques
        self.connection_start_time = None
        self.last_packet_time = None
        self.packet_counter = 0
        self.received_audio_count = 0
        self.received_data_count = 0
        
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
                # dynacast=True, # Supprimé car peut être obsolète
                # adaptive_stream=True, # Supprimé car peut être obsolète
            )
            
            # Assurer que l'URL utilise le protocole WebSocket
            connect_url = self.livekit_url
            if connect_url.startswith("http://"):
                connect_url = connect_url.replace("http://", "ws://")
            elif connect_url.startswith("https://"):
                connect_url = connect_url.replace("https://", "wss://")

            # Tentative de connexion
            await self.room.connect(connect_url, token, options=options)
            
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
                self.received_data_count, # Utiliser received_data_count pour les logs de données
                len(data_packet.data),
                time.time(),
                {"participant": data_packet.participant.identity if data_packet.participant else "unknown"}
            )
            
            if self.on_data_received:
                asyncio.create_task(self.on_data_received(data_packet.data, data_packet.participant, data_packet.kind))
                self.received_data_count += 1 
        
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
            audio_stream = AudioStream.from_track(
                track=track,
                sample_rate=48000,  # Utiliser un taux d'échantillonnage standard
                num_channels=1,     # Mono
            )
            async for audio_frame in audio_stream:
                self.logger.debug(f"Type of audio_frame: {type(audio_frame)}")
                if hasattr(audio_frame, 'frame'):
                    self.logger.debug(f"Type of audio_frame.frame: {type(audio_frame.frame)}")
                
                if self.on_audio_received:
                    # Extraire l'AudioFrame de l'AudioFrameEvent
                    frame = None
                    if hasattr(audio_frame, 'frame'):
                        frame = audio_frame.frame
                    elif hasattr(audio_frame, 'data'): # Si audio_frame est directement AudioFrame
                        frame = audio_frame
                    
                    if frame is None:
                        self.logger.error(f"💥 AudioFrame inattendu: {audio_frame}. Ni 'data' ni 'frame.data' trouvés.")
                        continue

                    audio_data = frame.data.tobytes()
                    
                    self.logger.audio_received(
                        self.received_audio_count, # Utiliser received_audio_count pour les logs audio
                        len(audio_data),
                        time.time(),
                        {
                            "participant": participant.identity,
                            "sample_rate": frame.sample_rate,
                            "channels": frame.num_channels
                        }
                    )
                    
                    await self.on_audio_received(audio_data, participant.identity, audio_frame)
                    self.received_audio_count += 1 # Incrémenter le compteur audio
            await audio_stream.aclose() # Fermer le flux après la lecture
        except Exception as e:
            self.logger.error(f"💥 Erreur lecture audio de {participant.identity}: {e}")
    
    async def publish_audio_track(self):
        """Publie une piste audio locale si elle n'existe pas déjà."""
        self.logger.info("Attempting to publish audio track...")
        if self.audio_track:
            self.logger.info("Piste audio déjà créée.")
            # Vérifier si la piste est déjà publiée via la publication
            if self.room and self.room.local_participant:
                for pub in self.room.local_participant.track_publications.values():
                    if pub.sid == self.audio_track.sid:
                        self.logger.info("Piste audio déjà publiée et active.")
                        return

        try:
            # Créer une piste audio locale
            # Créer une nouvelle source audio et une piste audio locale
            self.audio_source = rtc.AudioSource(48000, 1) # Sample rate 48kHz, 1 channel (mono) pour correspondre au récepteur
            self.audio_track = rtc.LocalAudioTrack.create_audio_track(name="microphone", source=self.audio_source)
            
            # Publier la piste audio
            options = rtc.TrackPublishOptions()

            publication = await self.room.local_participant.publish_track(self.audio_track, options)
            self.logger.success(f"Piste audio publiée: {publication.sid}. Track ID: {self.audio_track.sid}")
            self.logger.info(f"Published track kind: {publication.kind}, source: {publication.source}") # Nouveau log
        except Exception as e:
            self.logger.error(f"💥 Erreur lors de la publication de la piste audio: {e}")
            raise # Re-lancer l'exception pour la gestion d'erreur

    async def send_audio_frame(self, audio_data: bytes, sample_rate: int, channels: int, metadata: Optional[Dict] = None) -> bool:
        """
        Envoie un frame audio via la piste audio LiveKit.
        
        Args:
            audio_data: Données audio brutes (PCM).
            sample_rate: Fréquence d'échantillonnage.
            channels: Nombre de canaux.
            metadata: Métadonnées optionnelles.
        
        Returns:
            True si l'envoi réussit, False sinon.
        """
        if not self.audio_track:
            self.logger.error("❌ Piste audio non créée. Tentative de publication.")
            await self.publish_audio_track() # Tente de publier
            if not self.audio_track: # Vérifier si la création a réussi
                self.logger.error("❌ Échec de la création de la piste audio. Impossible d'envoyer des frames.")
                return False
        
        # Vérifier si la piste est publiée
        is_published = False
        if self.room and self.room.local_participant:
            for pub in self.room.local_participant.track_publications.values():
                if pub.track and pub.track.sid == self.audio_track.sid:
                    is_published = True
                    break
        
        if not is_published:
            self.logger.error("❌ Piste audio non publiée. Tentative de publication.")
            await self.publish_audio_track() # Tente de publier
            if not is_published: # Vérifier si la publication a réussi
                self.logger.error("❌ Échec de la publication de la piste audio. Impossible d'envoyer des frames.")
                return False

        try:
            # Créer un AudioFrame à partir des données brutes
            audio_frame = rtc.AudioFrame(
                audio_data,
                sample_rate,
                channels,
                len(audio_data) // (channels * 2) # 2 bytes par échantillon (int16)
            )
            
            # Envoyer le frame audio à la source audio directement
            await self.audio_source.capture_frame(audio_frame)
            
            self.packet_counter += 1
            self.logger.debug(f"🎵 AUDIO FRAME SENT | Packet #{self.packet_counter} | Size: {len(audio_data)} bytes | TS: {time.time()}, metadata: {metadata}")
            return True
        except Exception as e:
            self.logger.error(f"💥 Erreur lors de l'envoi du frame audio: {e}")
            raise # Re-lancer l'exception pour la gestion d'erreur

    async def send_audio_file(self, audio_file_path: Path, metadata: Optional[Dict] = None) -> bool:
        """
        Envoie un fichier audio via LiveKit en utilisant la piste audio.
        
        Args:
            audio_file_path: Chemin vers le fichier audio.
            metadata: Métadonnées optionnelles.
        
        Returns:
            True si l'envoi réussit, False sinon.
        """
        if not self.room or not self.room.isconnected:
            self.logger.error("❌ Pas de connexion LiveKit active")
            return False
        
        if not self.audio_track:
            await self.publish_audio_track() # Publier la piste si elle ne l'est pas
            if not self.audio_track: # Vérifier si la publication a réussi
                self.logger.error("❌ Échec de la publication de la piste audio.")
                return False

        send_start = time.time()
        
        try:
            with wave.open(str(audio_file_path), 'rb') as wav_file:
                sample_rate = wav_file.getframerate()
                channels = wav_file.getnchannels()
                
                self.logger.debug(f"🎵 Fichier WAV: sample_rate={sample_rate}, channels={channels}, sample_width={wav_file.getsampwidth()}")

                # LiveKit s'attend à du PCM 16 bits
                if wav_file.getsampwidth() != 2:
                    self.logger.error("❌ Le fichier WAV doit être en PCM 16 bits.")
                    return False

                if sample_rate != self.audio_source.sample_rate or channels != self.audio_source.num_channels:
                    self.logger.warning(f"⚠️ Incompatibilité: AudioSource ({self.audio_source.sample_rate}Hz, {self.audio_source.num_channels}ch) vs WAV ({sample_rate}Hz, {channels}ch). Ajustement de l'AudioSource.")
                    self.audio_source = rtc.AudioSource(sample_rate, channels)
                    self.audio_track = rtc.LocalAudioTrack.create_audio_track(name="microphone", source=self.audio_source)
                    await self.room.local_participant.publish_track(self.audio_track, rtc.TrackPublishOptions())

                # Lire et envoyer les frames audio par petits morceaux
                chunk_size = sample_rate // 10 # Envoyer 100ms de données à la fois
                while True:
                    audio_chunk = wav_file.readframes(chunk_size)
                    if not audio_chunk:
                        break
                    
                    await self.send_audio_frame(audio_chunk, sample_rate, channels, metadata)
            
            # Le compteur de paquets est déjà incrémenté dans send_audio_frame
            # self.packet_counter += 1
            self.logger.info(f"🎵 Fichier audio envoyé: {audio_file_path.name}")
            
            send_time = (time.time() - send_start) * 1000
            self.last_packet_time = time.time()
            
            self.logger.latency("envoi_fichier_audio", send_time)
            self.logger.success(f"Fichier audio envoyé: {audio_file_path.name}")
            
            return True
            
        except Exception as e:
            send_time = (time.time() - send_start) * 1000
            self.logger.latency("envoi_fichier_audio_échec", send_time)
            self.logger.error(f"💥 Erreur envoi fichier audio: {e}")
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
                reliable=True
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