import logging
import time
import colorama
from colorama import Fore, Style, Back
from typing import Optional, Dict, Any
import threading
from datetime import datetime

# Initialisation de colorama pour les logs en couleur
colorama.init()

class PipelineLogger:
    """
    Système de journalisation avancé pour le pipeline LiveKit
    avec codes couleur et métriques en temps réel
    """
    
    def __init__(self, component_name: str):
        self.component_name = component_name
        self.start_time = time.time()
        self.metrics = {
            'packets_sent': 0,
            'packets_received': 0,
            'total_latency': 0,
            'latency_count': 0,
            'errors': 0,
            'warnings': 0
        }
        self._lock = threading.Lock()
        
        # Configuration du logger
        self.logger = logging.getLogger(component_name)
        self.logger.setLevel(logging.DEBUG)
        
        # Éviter les doublons de handlers
        if not self.logger.handlers:
            # Handler pour la console avec formatage coloré
            ch = logging.StreamHandler()
            ch.setLevel(logging.DEBUG)
            
            # Format personnalisé pour inclure le timestamp relatif et le composant
            formatter = ColoredFormatter(
                '%(asctime)s.%(msecs)03d [%(reltime).3fs] %(component)s - %(levelname)s: %(message)s',
                datefmt='%H:%M:%S'
            )
            
            ch.setFormatter(formatter)
            self.logger.addHandler(ch)
            self.logger.propagate = False
    
    def _get_relative_time(self) -> float:
        """Retourne le temps relatif depuis le démarrage"""
        return time.time() - self.start_time
    
    def _log(self, level: int, msg: str, *args, **kwargs):
        """Log interne avec ajout des métadonnées"""
        with self._lock:
            # Ajouter le temps relatif depuis le démarrage
            extra = {
                'reltime': self._get_relative_time(),
                'component': f"[{self.component_name}]"
            }
            
            # Compter les erreurs et warnings
            if level == logging.ERROR:
                self.metrics['errors'] += 1
            elif level == logging.WARNING:
                self.metrics['warnings'] += 1
            
            self.logger.log(level, msg, *args, extra=extra, **kwargs)
    
    def debug(self, msg: str, *args, **kwargs):
        """Log de débogage (cyan)"""
        self._log(logging.DEBUG, msg, *args, **kwargs)
        
    def info(self, msg: str, *args, **kwargs):
        """Log d'information (vert)"""
        self._log(logging.INFO, msg, *args, **kwargs)
        
    def warning(self, msg: str, *args, **kwargs):
        """Log d'avertissement (jaune)"""
        self._log(logging.WARNING, msg, *args, **kwargs)
        
    def error(self, msg: str, *args, **kwargs):
        """Log d'erreur (rouge)"""
        self._log(logging.ERROR, msg, *args, **kwargs)
        
    def critical(self, msg: str, *args, **kwargs):
        """Log critique (magenta)"""
        self._log(logging.CRITICAL, msg, *args, **kwargs)
    
    def success(self, msg: str, *args, **kwargs):
        """Log de succès (vert brillant)"""
        colored_msg = f"{Fore.GREEN}{Style.BRIGHT}✅ {msg}{Style.RESET_ALL}"
        self._log(logging.INFO, colored_msg, *args, **kwargs)
    
    def audio_packet(self, packet_id: int, size: int, timestamp: float, metadata: Optional[Dict] = None):
        """Log spécifique pour les paquets audio avec formatage distinct"""
        with self._lock:
            self.metrics['packets_sent'] += 1
            
        metadata_str = f", metadata: {metadata}" if metadata else ""
        packet_msg = f"{Fore.BLUE}🎵 AUDIO PACKET #{packet_id}{Style.RESET_ALL} | Size: {Fore.YELLOW}{size} bytes{Style.RESET_ALL} | TS: {timestamp:.3f}{metadata_str}"
        self._log(logging.DEBUG, packet_msg)
    
    def audio_received(self, packet_id: int, size: int, timestamp: float, metadata: Optional[Dict] = None):
        """Log spécifique pour les paquets audio reçus"""
        with self._lock:
            self.metrics['packets_received'] += 1
            
        metadata_str = f", metadata: {metadata}" if metadata else ""
        packet_msg = f"{Fore.GREEN}🎧 AUDIO RECEIVED #{packet_id}{Style.RESET_ALL} | Size: {Fore.YELLOW}{size} bytes{Style.RESET_ALL} | TS: {timestamp:.3f}{metadata_str}"
        self._log(logging.DEBUG, packet_msg)
    
    def latency(self, component: str, value_ms: float):
        """Log spécifique pour les mesures de latence"""
        with self._lock:
            self.metrics['total_latency'] += value_ms
            self.metrics['latency_count'] += 1
        
        # Colorier selon la latence
        if value_ms < 100:
            color = Fore.GREEN
            icon = "🚀"
        elif value_ms < 300:
            color = Fore.YELLOW
            icon = "⚡"
        elif value_ms < 500:
            color = Fore.MAGENTA
            icon = "⏱️"
        else:
            color = Fore.RED
            icon = "🐌"
        
        latency_msg = f"{color}{icon} LATENCY{Style.RESET_ALL} | {component}: {color}{value_ms:.2f} ms{Style.RESET_ALL}"
        self._log(logging.INFO, latency_msg)
    
    def connection_event(self, event_type: str, details: str = ""):
        """Log spécifique pour les événements de connexion"""
        if event_type.lower() in ['connected', 'success', 'established']:
            icon = "🔗"
            color = Fore.GREEN
        elif event_type.lower() in ['disconnected', 'failed', 'error']:
            icon = "❌"
            color = Fore.RED
        elif event_type.lower() in ['connecting', 'attempting']:
            icon = "🔄"
            color = Fore.YELLOW
        else:
            icon = "📡"
            color = Fore.CYAN
        
        conn_msg = f"{color}{icon} CONNECTION{Style.RESET_ALL} | {event_type}: {details}"
        self._log(logging.INFO, conn_msg)
    
    def performance_metric(self, metric_name: str, value: float, unit: str = ""):
        """Log spécifique pour les métriques de performance"""
        perf_msg = f"{Fore.MAGENTA}📊 METRIC{Style.RESET_ALL} | {metric_name}: {Fore.CYAN}{value:.2f} {unit}{Style.RESET_ALL}"
        self._log(logging.INFO, perf_msg)
    
    def network_event(self, event_type: str, details: str = ""):
        """Log spécifique pour les événements réseau"""
        if "loss" in event_type.lower() or "drop" in event_type.lower():
            icon = "📉"
            color = Fore.RED
        elif "quality" in event_type.lower():
            icon = "📶"
            color = Fore.GREEN
        else:
            icon = "🌐"
            color = Fore.BLUE
        
        net_msg = f"{color}{icon} NETWORK{Style.RESET_ALL} | {event_type}: {details}"
        self._log(logging.INFO, net_msg)
    
    def get_metrics_summary(self) -> Dict[str, Any]:
        """Retourne un résumé des métriques collectées"""
        with self._lock:
            avg_latency = (self.metrics['total_latency'] / self.metrics['latency_count']) if self.metrics['latency_count'] > 0 else 0
            uptime = self._get_relative_time()
            
            return {
                'component': self.component_name,
                'uptime_seconds': uptime,
                'packets_sent': self.metrics['packets_sent'],
                'packets_received': self.metrics['packets_received'],
                'packet_loss_rate': max(0, (self.metrics['packets_sent'] - self.metrics['packets_received']) / max(1, self.metrics['packets_sent'])),
                'average_latency_ms': avg_latency,
                'total_errors': self.metrics['errors'],
                'total_warnings': self.metrics['warnings'],
                'packets_per_second': self.metrics['packets_sent'] / max(1, uptime)
            }
    
    def print_metrics_summary(self):
        """Affiche un résumé coloré des métriques"""
        metrics = self.get_metrics_summary()
        
        print(f"\n{Back.BLUE}{Fore.WHITE} MÉTRIQUES - {self.component_name} {Style.RESET_ALL}")
        print(f"⏱️  Uptime: {Fore.CYAN}{metrics['uptime_seconds']:.1f}s{Style.RESET_ALL}")
        print(f"📤 Paquets envoyés: {Fore.GREEN}{metrics['packets_sent']}{Style.RESET_ALL}")
        print(f"📥 Paquets reçus: {Fore.GREEN}{metrics['packets_received']}{Style.RESET_ALL}")
        print(f"📉 Taux de perte: {Fore.RED if metrics['packet_loss_rate'] > 0.05 else Fore.GREEN}{metrics['packet_loss_rate']:.2%}{Style.RESET_ALL}")
        print(f"⚡ Latence moyenne: {Fore.YELLOW}{metrics['average_latency_ms']:.2f}ms{Style.RESET_ALL}")
        print(f"🚀 Paquets/sec: {Fore.CYAN}{metrics['packets_per_second']:.2f}{Style.RESET_ALL}")
        print(f"❌ Erreurs: {Fore.RED}{metrics['total_errors']}{Style.RESET_ALL}")
        print(f"⚠️  Avertissements: {Fore.YELLOW}{metrics['total_warnings']}{Style.RESET_ALL}")
        print()


class ColoredFormatter(logging.Formatter):
    """Formateur personnalisé pour ajouter des couleurs aux logs"""
    
    COLORS = {
        logging.DEBUG: Fore.CYAN,
        logging.INFO: Fore.GREEN,
        logging.WARNING: Fore.YELLOW,
        logging.ERROR: Fore.RED,
        logging.CRITICAL: Fore.MAGENTA + Style.BRIGHT
    }
    
    def format(self, record):
        # Ajouter la couleur selon le niveau
        color = self.COLORS.get(record.levelno, "")
        
        # Formater le message de base
        formatted = super().format(record)
        
        # Appliquer la couleur au niveau de log seulement
        if color:
            # Remplacer le nom du niveau par sa version colorée
            level_name = record.levelname
            colored_level = f"{color}{level_name}{Style.RESET_ALL}"
            formatted = formatted.replace(level_name, colored_level, 1)
        
        return formatted


class MetricsCollector:
    """Collecteur global de métriques pour tous les composants"""
    
    def __init__(self):
        self.loggers: Dict[str, PipelineLogger] = {}
        self._lock = threading.Lock()
    
    def register_logger(self, logger: PipelineLogger):
        """Enregistre un logger pour la collecte de métriques"""
        with self._lock:
            self.loggers[logger.component_name] = logger
    
    def get_global_metrics(self) -> Dict[str, Any]:
        """Retourne les métriques globales de tous les composants"""
        with self._lock:
            global_metrics = {
                'total_packets_sent': 0,
                'total_packets_received': 0,
                'total_errors': 0,
                'total_warnings': 0,
                'components': {}
            }
            
            for name, logger in self.loggers.items():
                metrics = logger.get_metrics_summary()
                global_metrics['components'][name] = metrics
                global_metrics['total_packets_sent'] += metrics['packets_sent']
                global_metrics['total_packets_received'] += metrics['packets_received']
                global_metrics['total_errors'] += metrics['total_errors']
                global_metrics['total_warnings'] += metrics['total_warnings']
            
            return global_metrics
    
    def print_global_summary(self):
        """Affiche un résumé global de tous les composants"""
        metrics = self.get_global_metrics()
        
        print(f"\n{Back.MAGENTA}{Fore.WHITE} RÉSUMÉ GLOBAL DU PIPELINE {Style.RESET_ALL}")
        print(f"📊 Composants actifs: {Fore.CYAN}{len(self.loggers)}{Style.RESET_ALL}")
        print(f"📤 Total paquets envoyés: {Fore.GREEN}{metrics['total_packets_sent']}{Style.RESET_ALL}")
        print(f"📥 Total paquets reçus: {Fore.GREEN}{metrics['total_packets_received']}{Style.RESET_ALL}")
        print(f"❌ Total erreurs: {Fore.RED}{metrics['total_errors']}{Style.RESET_ALL}")
        print(f"⚠️  Total avertissements: {Fore.YELLOW}{metrics['total_warnings']}{Style.RESET_ALL}")
        
        # Afficher les métriques par composant
        for name, comp_metrics in metrics['components'].items():
            print(f"\n{Fore.BLUE}▶ {name}{Style.RESET_ALL}")
            print(f"  📤 {comp_metrics['packets_sent']} | 📥 {comp_metrics['packets_received']} | "
                  f"⚡ {comp_metrics['average_latency_ms']:.1f}ms | "
                  f"❌ {comp_metrics['total_errors']} | ⚠️ {comp_metrics['total_warnings']}")


# Instance globale du collecteur de métriques
metrics_collector = MetricsCollector()