from werkzeug.middleware.dispatcher import Dispatcher
from app import app

# Créez un adaptateur WSGI explicite si nécessaire,
# bien que Flask soit déjà une application WSGI.
# Cela peut aider à résoudre des problèmes d'environnement.
application = Dispatcher({'/': app})

if __name__ == '__main__':
    # Ce bloc est principalement pour les tests locaux
    from waitress import serve
    serve(application, host='0.0.0.0', port=8000)