import os
from flask import Flask, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

# Load environment variables from .env if present
load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'))

app = Flask(__name__)
CORS(app) # Active CORS pour toutes les routes

@app.route('/')
def home():
    return "Bienvenue sur le backend Flask!"

@app.route('/api/data')
def get_data():
    data = {
        "message": "Données du backend Flask",
        "version": "1.0"
    }
    return jsonify(data)

if __name__ == '__main__':
    port = int(os.getenv('BACKEND_PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
