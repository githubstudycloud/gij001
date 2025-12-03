#!/usr/bin/env python3
"""
Create configuration files in GitLab repository using GitLab API.

Usage:
  python create_gitlab_configs.py                    # Use token from .env file
  python create_gitlab_configs.py <GITLAB_TOKEN>    # Use provided token
  python create_gitlab_configs.py --overwrite       # Overwrite existing files
  python create_gitlab_configs.py <TOKEN> --overwrite
"""
import sys
import os
import json
import urllib.request
import urllib.parse
import urllib.error

# GitLab configuration (can be overridden by .env file)
GITLAB_URL = 'http://192.168.0.99:8929'
PROJECT_PATH = 'xz01/springconfig'
BRANCH = 'main'

# Configuration files to create
# Structure: config/env{profile}/{application}.properties
# profile = test, beta, pro (environment)
# application = GlobalConfig, project1-v1 (config name)
CONFIG_FILES = {
    'config/envtest/GlobalConfig.properties': '''# ============================================
# Global Configuration - Test Environment
# ============================================

# Application Info
app.env=test
app.version=1.0.0

# Database - Common Settings
db.pool.min-size=5
db.pool.max-size=20
db.pool.timeout=30000

# Redis - Common Settings
redis.timeout=3000
redis.max-total=50
redis.max-idle=10

# Log Level
log.level.root=DEBUG
log.level.sql=DEBUG

# Feature Flags
feature.debug-mode=true
feature.mock-enabled=true
''',
    'config/envtest/project1-v1.properties': '''# ============================================
# Project1 Configuration - Test Environment
# ============================================

# Application
project1.name=Project One
project1.description=Test environment configuration

# Database
project1.db.url=jdbc:mysql://test-db:3306/project1_test
project1.db.username=project1_test
project1.db.password=test123

# Redis
project1.redis.host=test-redis
project1.redis.port=6379
project1.redis.database=0

# API Settings
project1.api.base-url=http://test-api.example.com
project1.api.timeout=5000

# Custom Settings
project1.custom.setting1=test-value-1
project1.custom.setting2=test-value-2
''',
    'config/envbeta/GlobalConfig.properties': '''# ============================================
# Global Configuration - Beta Environment
# ============================================

# Application Info
app.env=beta
app.version=1.0.0

# Database - Common Settings
db.pool.min-size=10
db.pool.max-size=50
db.pool.timeout=30000

# Redis - Common Settings
redis.timeout=3000
redis.max-total=100
redis.max-idle=20

# Log Level
log.level.root=INFO
log.level.sql=INFO

# Feature Flags
feature.debug-mode=true
feature.mock-enabled=false
''',
    'config/envbeta/project1-v1.properties': '''# ============================================
# Project1 Configuration - Beta Environment
# ============================================

# Application
project1.name=Project One
project1.description=Beta environment configuration

# Database
project1.db.url=jdbc:mysql://beta-db:3306/project1_beta
project1.db.username=project1_beta
project1.db.password=beta456

# Redis
project1.redis.host=beta-redis
project1.redis.port=6379
project1.redis.database=1

# API Settings
project1.api.base-url=http://beta-api.example.com
project1.api.timeout=5000

# Custom Settings
project1.custom.setting1=beta-value-1
project1.custom.setting2=beta-value-2
''',
    'config/envpro/GlobalConfig.properties': '''# ============================================
# Global Configuration - Production Environment
# ============================================

# Application Info
app.env=pro
app.version=1.0.0

# Database - Common Settings
db.pool.min-size=20
db.pool.max-size=100
db.pool.timeout=30000

# Redis - Common Settings
redis.timeout=3000
redis.max-total=200
redis.max-idle=50

# Log Level
log.level.root=WARN
log.level.sql=ERROR

# Feature Flags
feature.debug-mode=false
feature.mock-enabled=false
''',
    'config/envpro/project1-v1.properties': '''# ============================================
# Project1 Configuration - Production Environment
# ============================================

# Application
project1.name=Project One
project1.description=Production environment configuration

# Database
project1.db.url=jdbc:mysql://pro-db-master:3306/project1_pro
project1.db.username=project1_pro
project1.db.password=ENC(encrypted_password_here)

# Redis
project1.redis.host=pro-redis-cluster
project1.redis.port=6379
project1.redis.database=2

# API Settings
project1.api.base-url=http://api.example.com
project1.api.timeout=3000

# Custom Settings
project1.custom.setting1=pro-value-1
project1.custom.setting2=pro-value-2
'''
}


def load_env_file():
    """Load configuration from .env file."""
    env_paths = [
        os.path.join(os.path.dirname(__file__), '..', '..', '..', '.env'),
        os.path.join(os.path.dirname(__file__), '..', '.env'),
        '.env'
    ]

    for env_path in env_paths:
        if os.path.exists(env_path):
            with open(env_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        os.environ.setdefault(key.strip(), value.strip())
            return True
    return False


def get_project_id(token):
    """Get project ID from project path."""
    encoded_path = urllib.parse.quote(PROJECT_PATH, safe='')
    url = f"{GITLAB_URL}/api/v4/projects/{encoded_path}"

    req = urllib.request.Request(url)
    req.add_header('PRIVATE-TOKEN', token)

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            return data['id']
    except urllib.error.HTTPError as e:
        print(f"Error getting project: {e.code} {e.reason}")
        try:
            error_body = e.read().decode('utf-8')
            print(f"  Details: {error_body}")
        except:
            pass
        return None
    except urllib.error.URLError as e:
        print(f"Connection error: {e.reason}")
        return None


def file_exists(token, project_id, file_path):
    """Check if file already exists in repository."""
    encoded_path = urllib.parse.quote(file_path, safe='')
    url = f"{GITLAB_URL}/api/v4/projects/{project_id}/repository/files/{encoded_path}?ref={BRANCH}"

    req = urllib.request.Request(url)
    req.add_header('PRIVATE-TOKEN', token)

    try:
        with urllib.request.urlopen(req, timeout=10):
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise


def create_file(token, project_id, file_path, content, overwrite=False):
    """Create a file in GitLab repository."""
    encoded_path = urllib.parse.quote(file_path, safe='')
    url = f"{GITLAB_URL}/api/v4/projects/{project_id}/repository/files/{encoded_path}"

    exists = file_exists(token, project_id, file_path)

    if exists and not overwrite:
        return True, 'skipped (exists)'

    data = {
        'branch': BRANCH,
        'content': content,
        'commit_message': f"{'Update' if exists else 'Create'} {file_path}"
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode('utf-8'),
        method='PUT' if exists else 'POST'
    )
    req.add_header('PRIVATE-TOKEN', token)
    req.add_header('Content-Type', 'application/json')

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return True, 'updated' if exists else 'created'
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        return False, f"{e.code}: {error_body}"


def main():
    # Parse arguments
    token = None
    overwrite = False

    for arg in sys.argv[1:]:
        if arg == '--overwrite' or arg == '-f':
            overwrite = True
        elif not arg.startswith('-'):
            token = arg

    # Load .env file
    load_env_file()

    # Get token from env if not provided
    if not token:
        token = os.environ.get('GITLAB_TOKEN')

    if not token:
        print("Usage: python create_gitlab_configs.py [TOKEN] [--overwrite]")
        print("\nOptions:")
        print("  TOKEN        GitLab access token (or set GITLAB_TOKEN in .env)")
        print("  --overwrite  Overwrite existing files (default: skip)")
        print("\nTo get a GitLab token:")
        print("  1. Go to GitLab -> User Settings -> Access Tokens")
        print("  2. Create a token with 'api' scope")
        sys.exit(1)

    print(f"GitLab URL: {GITLAB_URL}")
    print(f"Project: {PROJECT_PATH}")
    print(f"Branch: {BRANCH}")
    print(f"Overwrite: {'Yes' if overwrite else 'No (skip existing)'}")
    print()

    # Get project ID
    project_id = get_project_id(token)
    if not project_id:
        print("Failed to get project ID. Check your token and project path.")
        sys.exit(1)

    print(f"Project ID: {project_id}")
    print()

    # Create each config file
    success_count = 0
    skip_count = 0
    for file_path, content in CONFIG_FILES.items():
        print(f"  {file_path}...", end=' ')
        success, result = create_file(token, project_id, file_path, content, overwrite)
        if success:
            print(f"[{result}]")
            if 'skipped' in result:
                skip_count += 1
            else:
                success_count += 1
        else:
            print(f"[FAILED: {result}]")

    print()
    print(f"Results: {success_count} created/updated, {skip_count} skipped, {len(CONFIG_FILES) - success_count - skip_count} failed")

    if success_count + skip_count == len(CONFIG_FILES):
        print("\nConfiguration files are ready in GitLab!")
        print(f"\nTest with Config Server:")
        print(f"  curl http://localhost:8888/project1-v1/test/{BRANCH}")
        print(f"  curl http://localhost:8888/GlobalConfig/pro/{BRANCH}")


if __name__ == '__main__':
    main()
