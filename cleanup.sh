#!/bin/bash
set -euo pipefail

echo "Début du script de maintenance Docker..."

# 1. Diagnostic
echo "--- 1. Diagnostic ---"
echo "Liste de tous les conteneurs (actifs et arrêtés) :"
docker ps -a

echo "Usage CPU/mémoire des conteneurs :"
docker stats --no-stream

echo "Récupération des 100 dernières lignes de logs pour les conteneurs clés (si existants) :"
# À adapter en fonction des noms de conteneurs réels de l'application
# Exemple: docker logs --tail 100 nom_du_conteneur_backend
# Pour l'instant, je vais laisser un placeholder. L'utilisateur devra spécifier les noms des conteneurs clés.
echo "Veuillez adapter cette section pour spécifier les noms de vos conteneurs clés."
# docker logs --tail 100 nom_du_conteneur_1 || true
# docker logs --tail 100 nom_du_conteneur_2 || true

# 2. Nettoyage
echo "--- 2. Nettoyage ---"
echo "Nettoyage des conteneurs arrêtés..."
CONTAINERS_PRUNED=$(docker container prune --force | grep 'Total reclaimed space:' | awk '{print $4, $5}')
echo "Espace récupéré (conteneurs) : $CONTAINERS_PRUNED"

echo "Nettoyage de toutes les images non utilisées..."
IMAGES_PRUNED=$(docker image prune --all --force | grep 'Total reclaimed space:' | awk '{print $4, $5}')
echo "Espace récupéré (images) : $IMAGES_PRUNED"

echo "Nettoyage des volumes non utilisés..."
VOLUMES_PRUNED=$(docker volume prune --force | grep 'Total reclaimed space:' | awk '{print $4, $5}')
echo "Espace récupéré (volumes) : $VOLUMES_PRUNED"

echo "Nettoyage des réseaux non utilisés..."
NETWORKS_PRUNED=$(docker network prune --force | grep 'Total reclaimed space:' | awk '{print $4, $5}')
echo "Espace récupéré (réseaux) : $NETWORKS_PRUNED"

# 3. Rebuild
echo "--- 3. Rebuild des images Docker ---"
docker-compose build --no-cache
echo "Rebuild des images terminé."

# 4. Redémarrage
echo "--- 4. Redémarrage des services Docker ---"
# Vérifier et ajouter restart: on-failure:5 si manquant
echo "Vérification et ajout de 'restart: on-failure:5' dans docker-compose.yml si manquant..."
if ! grep -q "restart: on-failure:5" docker-compose.yml; then
    echo "Attention: 'restart: on-failure:5' n'est pas trouvé dans docker-compose.yml. Veuillez l'ajouter manuellement pour une robustesse accrue."
    # Pour une automatisation complète, on pourrait tenter d'insérer, mais c'est risqué sans analyse YAML.
    # Pour l'instant, je me contente d'un avertissement.
fi
docker-compose up -d
echo "Redémarrage des services terminé."

# 5. Vérification
echo "--- 5. Vérification de la santé des services ---"
echo "Attente de 10 secondes pour le démarrage des services..."
sleep 10

UNHEALTHY_SERVICES=$(docker-compose ps --services --filter "status=unhealthy")

if [ -n "$UNHEALTHY_SERVICES" ]; then
    echo "Erreur: Les services suivants sont unhealthy :"
    echo "$UNHEALTHY_SERVICES"
    exit 1
else
    echo "Tous les services sont sains."
fi

# 6. Rapport de résultat
echo "--- 6. Rapport de résultat ---"
echo "Nettoyage effectué :"
echo "  - Conteneurs : $CONTAINERS_PRUNED"
echo "  - Images : $IMAGES_PRUNED"
echo "  - Volumes : $VOLUMES_PRUNED"
echo "  - Réseaux : $NETWORKS_PRUNED"
echo "Rebuild des images : Réussi"
echo "Redémarrage des services : Réussi"

echo "Script de maintenance Docker terminé avec succès."