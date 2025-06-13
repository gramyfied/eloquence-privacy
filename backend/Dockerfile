# Dockerfile pour l'API Backend Eloquence
FROM python:3.11-slim

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Répertoire de travail
WORKDIR /app

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copie des fichiers de requirements
COPY requirements.txt .

# Installation des dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code de l'application
COPY . .

# Exposition du port
EXPOSE 8000

# Endpoint de santé simple
RUN echo 'from fastapi import FastAPI\nfrom fastapi.responses import JSONResponse\nimport uvicorn\n\napp = FastAPI(title="Eloquence API", version="1.0.0")\n\n@app.get("/health")\nasync def health_check():\n    return {"status": "healthy", "service": "eloquence-api"}\n\n@app.get("/")\nasync def root():\n    return {"message": "Eloquence API Backend"}\n\nif __name__ == "__main__":\n    uvicorn.run(app, host="0.0.0.0", port=8000)' > simple_api.py

# Commande de démarrage
CMD ["python", "simple_api.py"]