import os

from app import create_app
from app.home import bp

app = create_app(os.getenv('INAGEOPORTAL_ENV') or 'dev')
app.register_blueprint(bp)