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
    # Make the SQLAlchemy engine resilient to serverless/Postgres idle disconnects
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,      # validate connection before each checkout
        'pool_recycle': 300,        # recycle connections periodically (seconds)
        'pool_size': 5,
        'max_overflow': 5,
        'pool_timeout': 5,
    }
    
    # Neon PostgreSQL configuration (do not enforce at base level so testing can work)
    NEON_DATABASE_URL = os.environ.get('NEON_DATABASE_URL')
    SQLALCHEMY_DATABASE_URI = _normalize_sqlalchemy_uri(NEON_DATABASE_URL or '')
    
    # API Keys
    EXERCISEDB_API_KEY = os.environ.get('EXERCISEDB_API_KEY') or 'fe937754cbmshedd7dea0ed0cadbp13bdb7jsnb128a01e99a5'
    EXERCISEDB_HOST = 'exercisedb.p.rapidapi.com'
    EXERCISEDB_BASE_URL = 'https://exercisedb.p.rapidapi.com'
    
    # Email Configuration (Gmail SMTP)
    MAIL_SERVER = 'smtp.gmail.com'
    MAIL_PORT = 587
    MAIL_USE_TLS = True
    MAIL_USERNAME = os.environ.get('GMAIL_USERNAME')
    MAIL_PASSWORD = os.environ.get('GMAIL_APP_PASSWORD')
    MAIL_DEFAULT_SENDER = os.environ.get('GMAIL_USERNAME')

class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    # Require Neon in development as well; remove SQLite fallback
    # Only raise error if explicitly in development mode and URL is missing
    # This allows Railway to work even if FLASK_ENV is not set (will use production config)
    neon_url = os.environ.get('NEON_DATABASE_URL')
    if not neon_url:
        # Don't raise error during class definition - check at runtime
        pass
    SQLALCHEMY_DATABASE_URI = _normalize_sqlalchemy_uri(neon_url or '')

class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    # Require Neon PostgreSQL for production
    # Don't raise error during class definition - check at runtime
    neon_url = os.environ.get('NEON_DATABASE_URL')
    if not neon_url:
        # Log warning but don't crash - allows Railway to start and show proper error
        import sys
        print("[WARNING] NEON_DATABASE_URL not set - database features will not work", file=sys.stderr)
    SQLALCHEMY_DATABASE_URI = _normalize_sqlalchemy_uri(neon_url or '')

class TestingConfig(Config):
    """Testing configuration"""
    TESTING = True
    # Enforce Neon even in testing to avoid any SQLite usage
    if not os.environ.get('NEON_DATABASE_URL'):
        raise ValueError("NEON_DATABASE_URL must be set for testing")
    SQLALCHEMY_DATABASE_URI = _normalize_sqlalchemy_uri(os.environ.get('NEON_DATABASE_URL'))

# Configuration dictionary
# Default to production if FLASK_ENV is not set (for Railway/deployment)
default_config = 'production' if os.environ.get('RAILWAY_ENVIRONMENT') or os.environ.get('PORT') else 'development'
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': ProductionConfig if (os.environ.get('RAILWAY_ENVIRONMENT') or os.environ.get('PORT')) else DevelopmentConfig
}
