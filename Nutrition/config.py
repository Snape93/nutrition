import os
import tempfile
from dotenv import load_dotenv

# Load environment variables (commented out for testing)
# load_dotenv()

class Config:
    """Base configuration class"""
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    
    # Database configuration
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Neon PostgreSQL configuration (do not enforce at base level so testing can work)
    NEON_DATABASE_URL = os.environ.get('NEON_DATABASE_URL')
    SQLALCHEMY_DATABASE_URI = NEON_DATABASE_URL or ''
    
    # API Keys
    EXERCISEDB_API_KEY = os.environ.get('EXERCISEDB_API_KEY') or 'fe937754cbmshedd7dea0ed0cadbp13bdb7jsnb128a01e99a5'
    EXERCISEDB_HOST = 'exercisedb.p.rapidapi.com'
    EXERCISEDB_BASE_URL = 'https://exercisedb.p.rapidapi.com'

class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    # Require Neon in development
    if os.environ.get('FLASK_ENV') != 'testing':
        if not os.environ.get('NEON_DATABASE_URL'):
            raise ValueError("NEON_DATABASE_URL must be set for development")
    SQLALCHEMY_DATABASE_URI = os.environ.get('NEON_DATABASE_URL')

class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    # Require Neon PostgreSQL for production
    if os.environ.get('FLASK_ENV') != 'testing':
        if not os.environ.get('NEON_DATABASE_URL'):
            raise ValueError("NEON_DATABASE_URL environment variable must be set for production")
    SQLALCHEMY_DATABASE_URI = os.environ.get('NEON_DATABASE_URL')

class TestingConfig(Config):
    """Testing configuration"""
    TESTING = True
    # Prefer file-based SQLite to avoid multiple-connection issues with in-memory DB
    SQLALCHEMY_DATABASE_URI = (
        os.environ.get('TEST_DATABASE_URL')
        or f"sqlite:///{os.path.join(tempfile.gettempdir(), 'nutrition_test.db')}"
    )

# Configuration dictionary
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}
