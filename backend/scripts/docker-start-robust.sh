#!/bin/bash

# Script de démarrage robuste pour Docker Compose
# Ce script gère le démarrage, l'arrêt et la surveillance des services

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages colorés
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier si Docker est en cours d'exécution
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker n'est pas en cours d'exécution. Veuillez démarrer Docker Desktop."
        exit 1
    fi
    log_success "Docker est en cours d'exécution"
}

# Fonction pour nettoyer les anciens conteneurs
cleanup() {
    log_info "Nettoyage des anciens conteneurs..."
    docker-compose -f docker-compose.robust.yml down --remove-orphans
    docker system prune -f
    log_success "Nettoyage terminé"
}

# Fonction pour construire les images
build_images() {
    log_info "Construction des images Docker..."
    docker-compose -f docker-compose.robust.yml build --no-cache
    log_success "Images construites avec succès"
}

# Fonction pour démarrer les services
start_services() {
    log_info "Démarrage des services..."
    docker-compose -f docker-compose.robust.yml up -d
    
    # Attendre que les services soient prêts
    log_info "Attente que les services soient prêts..."
    sleep 30
    
    # Vérifier l'état des services
    check_services_health
}

# Fonction pour vérifier la santé des services
check_services_health() {
    log_info "Vérification de la santé des services..."
    
    services=("redis" "livekit" "asr-service" "tts-service" "api")
    
    for service in "${services[@]}"; do
        if docker-compose -f docker-compose.robust.yml ps | grep -q "$service.*Up"; then
            log_success "Service $service: OK"
        else
            log_error "Service $service: ÉCHEC"
            docker-compose -f docker-compose.robust.yml logs "$service" | tail -20
        fi
    done
}

# Fonction pour afficher les logs
show_logs() {
    log_info "Affichage des logs en temps réel..."
    docker-compose -f docker-compose.robust.yml logs -f
}

# Fonction pour arrêter les services
stop_services() {
    log_info "Arrêt des services..."
    docker-compose -f docker-compose.robust.yml down
    log_success "Services arrêtés"
}

# Fonction pour redémarrer les services
restart_services() {
    log_info "Redémarrage des services..."
    stop_services
    start_services
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  start     Démarrer tous les services"
    echo "  stop      Arrêter tous les services"
    echo "  restart   Redémarrer tous les services"
    echo "  build     Construire les images Docker"
    echo "  cleanup   Nettoyer les anciens conteneurs"
    echo "  logs      Afficher les logs en temps réel"
    echo "  status    Vérifier l'état des services"
    echo "  help      Afficher cette aide"
    echo ""
}

# Menu principal
case "${1:-start}" in
    "start")
        check_docker
        cleanup
        build_images
        start_services
        log_success "Tous les services sont démarrés!"
        log_info "API disponible sur: http://localhost:8000"
        log_info "LiveKit disponible sur: http://localhost:7880"
        log_info "Redis disponible sur: localhost:6380"
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        check_docker
        restart_services
        ;;
    "build")
        check_docker
        build_images
        ;;
    "cleanup")
        cleanup
        ;;
    "logs")
        show_logs
        ;;
    "status")
        check_services_health
        ;;
    "help")
        show_help
        ;;
    *)
        log_error "Option inconnue: $1"
        show_help
        exit 1
        ;;
esac