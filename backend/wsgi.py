from app import app

# Flask est déjà une application WSGI
application = app

if __name__ == '__main__':
    # Ce bloc est principalement pour les tests locaux
    from waitress import serve
    serve(application, host='0.0.0.0', port=8000)