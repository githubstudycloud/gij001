#!/bin/bash
# ============================================
# Create GitLab Config Files via API
# Usage: ./create_gitlab_configs.sh [--overwrite]
# ============================================

# Load .env file
if [ -f "../../../.env" ]; then
    export $(grep -v '^#' ../../../.env | xargs)
fi

TOKEN="${GITLAB_TOKEN:-}"
GITLAB="${GITLAB_URL:-http://192.168.0.99:8929}"
PROJECT="xz01%2Fspringconfig"
BRANCH="main"
OVERWRITE=false

# Parse arguments
for arg in "$@"; do
    if [ "$arg" == "--overwrite" ] || [ "$arg" == "-f" ]; then
        OVERWRITE=true
    fi
done

if [ -z "$TOKEN" ]; then
    echo "Error: GITLAB_TOKEN not set"
    echo "Set it in .env file or: export GITLAB_TOKEN=your_token"
    exit 1
fi

echo "GitLab: $GITLAB"
echo "Project: xz01/springconfig"
echo "Branch: $BRANCH"
echo "Overwrite: $OVERWRITE"
echo ""

# Function to create or update file
create_file() {
    local FILE_PATH="$1"
    local CONTENT="$2"
    local ENCODED_PATH=$(echo "$FILE_PATH" | sed 's/\//%2F/g')

    # Check if file exists
    local EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "PRIVATE-TOKEN: $TOKEN" \
        "$GITLAB/api/v4/projects/$PROJECT/repository/files/$ENCODED_PATH?ref=$BRANCH")

    if [ "$EXISTS" == "200" ] && [ "$OVERWRITE" == "false" ]; then
        echo "  $FILE_PATH... [skipped (exists)]"
        return 0
    fi

    local METHOD="POST"
    local ACTION="Create"
    if [ "$EXISTS" == "200" ]; then
        METHOD="PUT"
        ACTION="Update"
    fi

    # Escape content for JSON
    local JSON_CONTENT=$(echo "$CONTENT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

    local RESULT=$(curl -s -X $METHOD \
        -H "PRIVATE-TOKEN: $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"branch\": \"$BRANCH\", \"content\": $JSON_CONTENT, \"commit_message\": \"$ACTION $FILE_PATH\"}" \
        "$GITLAB/api/v4/projects/$PROJECT/repository/files/$ENCODED_PATH")

    if echo "$RESULT" | grep -q "file_path"; then
        if [ "$METHOD" == "PUT" ]; then
            echo "  $FILE_PATH... [updated]"
        else
            echo "  $FILE_PATH... [created]"
        fi
    else
        echo "  $FILE_PATH... [FAILED: $RESULT]"
    fi
}

echo "Creating configuration files..."

# envtest
create_file "config/envtest/GlobalConfig.properties" "# Global Configuration - Test Environment
app.env=test
app.version=1.0.0
db.pool.min-size=5
db.pool.max-size=20
db.pool.timeout=30000
redis.timeout=3000
redis.max-total=50
redis.max-idle=10
log.level.root=DEBUG
log.level.sql=DEBUG
feature.debug-mode=true
feature.mock-enabled=true"

create_file "config/envtest/project1-v1.properties" "# Project1 Configuration - Test Environment
project1.name=Project One
project1.description=Test environment configuration
project1.db.url=jdbc:mysql://test-db:3306/project1_test
project1.db.username=project1_test
project1.db.password=test123
project1.redis.host=test-redis
project1.redis.port=6379
project1.redis.database=0
project1.api.base-url=http://test-api.example.com
project1.api.timeout=5000
project1.custom.setting1=test-value-1
project1.custom.setting2=test-value-2"

# envbeta
create_file "config/envbeta/GlobalConfig.properties" "# Global Configuration - Beta Environment
app.env=beta
app.version=1.0.0
db.pool.min-size=10
db.pool.max-size=50
db.pool.timeout=30000
redis.timeout=3000
redis.max-total=100
redis.max-idle=20
log.level.root=INFO
log.level.sql=INFO
feature.debug-mode=true
feature.mock-enabled=false"

create_file "config/envbeta/project1-v1.properties" "# Project1 Configuration - Beta Environment
project1.name=Project One
project1.description=Beta environment configuration
project1.db.url=jdbc:mysql://beta-db:3306/project1_beta
project1.db.username=project1_beta
project1.db.password=beta456
project1.redis.host=beta-redis
project1.redis.port=6379
project1.redis.database=1
project1.api.base-url=http://beta-api.example.com
project1.api.timeout=5000
project1.custom.setting1=beta-value-1
project1.custom.setting2=beta-value-2"

# envpro
create_file "config/envpro/GlobalConfig.properties" "# Global Configuration - Production Environment
app.env=pro
app.version=1.0.0
db.pool.min-size=20
db.pool.max-size=100
db.pool.timeout=30000
redis.timeout=3000
redis.max-total=200
redis.max-idle=50
log.level.root=WARN
log.level.sql=ERROR
feature.debug-mode=false
feature.mock-enabled=false"

create_file "config/envpro/project1-v1.properties" "# Project1 Configuration - Production Environment
project1.name=Project One
project1.description=Production environment configuration
project1.db.url=jdbc:mysql://pro-db-master:3306/project1_pro
project1.db.username=project1_pro
project1.db.password=ENC(encrypted_password_here)
project1.redis.host=pro-redis-cluster
project1.redis.port=6379
project1.redis.database=2
project1.api.base-url=http://api.example.com
project1.api.timeout=3000
project1.custom.setting1=pro-value-1
project1.custom.setting2=pro-value-2"

echo ""
echo "Done! Test with:"
echo "  curl http://localhost:8888/project1-v1/test/$BRANCH"
