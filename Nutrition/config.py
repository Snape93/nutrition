import os
import tempfile
from dotenv import load_dotenv

# Load environment variables from .env so NEON_DATABASE_URL is picked up automatically
load_dotenv()

def _normalize_sqlalchemy_uri(uri: str) -> str:
    """Normalize sqlite relative paths to absolute to avoid CWD issues on Windows."""
    if not uri:
        return uri
    if uri.startswith('sqlite:///') and not uri.startswith('sqlite:////'):
        base_dir = os.path.dirname(__file__)
        rel_path = uri.replace('sqlite:///','',1)
        abs_path = os.path.abspath(os.path.join(base_dir, rel_path))
        abs_path = abs_path.replace('\\', '/')
        return f'sqlite:///{abs_path}'
    return uri

class Config:
    """Base configuration class"""
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    
    # Database configuration
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Neon PostgreSQL configuration (do not enforce at base level so testing can work)
    NEON_DATABASE_URL = os.environ.get('NEON_DATABASE_URL')
    SQLALCHEMY_DATABASE_URI = _normalize_sqlalchemy_uri(NEON_DATABASE_URL or '')
    
    # API Keys
    EXERCISEDB_API_KEY = os.environ.get('EXERCISEDB_API_KEY') or 'fe937754cbmshedd7dea0ed0cadbp13bdb7jsnb128a01e99a5'
    EXERCISEDB_HOST = 'exercisedb.p.rapidapi.com'
    EXERCISEDB_BASE_URL = 'https://exercisedb.p.rapidapi.com'

class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    # Require Neon in development as well; remove SQLite fallback
    if not os.environ.get('NEON_DATABASE_URL'):
        raise ValueError("NEON_DATABASE_URL must be set for development")
    SQLALCHEMY_DATABASE_URI = _normalize_sqlalchemy_uri(os.environ.get('NEON_DATABASE_URL'))

class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    # Require Neon PostgreSQL for production
    if os.environ.get('FLASK_ENV') != 'testing':
        if not os.environ.get('NEON_DATABASE_URL'):
            raise ValueError("NEON_DATABASE_URL environment variable must be set for production")
    SQLALCHEMY_DATABASE_URI = _normalize_sqlalchemy_uri(os.environ.get('NEON_DATABASE_URL'))

class TestingConfig(Config):
    """Testing configuration"""
    TESTING = True
    # Enforce Neon even in testing to avoid any SQLite usage
    if not os.environ.get('NEON_DATABASE_URL'):
        raise ValueError("NEON_DATABASE_URL must be set for testing")
    SQLALCHEMY_DATABASE_URI = _normalize_sqlalchemy_uri(os.environ.get('NEON_DATABASE_URL'))

# Configuration dictionary
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}
