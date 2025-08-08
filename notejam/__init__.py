from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from flask_mail import Mail
from flask_migrate import Migrate
import os

from notejam.config import Config, DevelopmentConfig, ProductionConfig, TestingConfig

config_map = {
    'production': ProductionConfig,
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'dbconfig': Config
}

env = os.getenv('ENVIRONMENT', 'development')
config_class = config_map.get(env, DevelopmentConfig)

app = Flask(__name__)
app.config.from_object(config_class)

print(f"ENVIRONMENT: {env}")
print(f"SQLALCHEMY_DATABASE_URI: {app.config.get('SQLALCHEMY_DATABASE_URI')}")

db = SQLAlchemy(app)
migrate = Migrate(app, db)

@app.before_first_request
def create_tables():
    if app.config['SQLALCHEMY_DATABASE_URI'].startswith('sqlite'):
        db.create_all()

login_manager = LoginManager()
login_manager.login_view = "signin"
login_manager.init_app(app)

mail = Mail()
mail.init_app(app)

from notejam import views
