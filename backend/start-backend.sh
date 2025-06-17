#!/bin/bash
set -e

echo "Démarrage du Backend API..."
echo "Python version: $(python --version)"
echo "Pip packages:"
pip list | grep -E "(fastapi|uvicorn|celery)"

# Vérifier que l'app peut démarrer
python -c "import app; print('Backend API importé avec succès')"

# Démarrer avec retry
for i in {1..3}; do
    echo "Tentative de démarrage $i/3"
    python run_flask_dev.py && break
    echo "Échec tentative $i, attente 10s..."
    sleep 10
done