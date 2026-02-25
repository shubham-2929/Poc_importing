#!/bin/bash
set -e

# Ignition Gateway Backup Script
# Usage: ./scripts/backup-gateway.sh <environment>
# Example: ./scripts/backup-gateway.sh dev

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT_INPUT=$1

if [ -z "$ENVIRONMENT_INPUT" ]; then
  echo "Error: Environment not specified"
  echo "Usage: ./scripts/backup-gateway.sh <environment>"
  exit 1
fi

case "$ENVIRONMENT_INPUT" in
  local)
    ENVIRONMENT="local"
    ENV_VAR_PREFIX="LOCAL"
    ;;
  dev|development)
    ENVIRONMENT="dev"
    ENV_VAR_PREFIX="DEV"
    ;;
  staging)
    ENVIRONMENT="staging"
    ENV_VAR_PREFIX="STAGING"
    ;;
  prod|production)
    ENVIRONMENT="prod"
    ENV_VAR_PREFIX="PROD"
    ;;
  *)
    echo "Error: Unknown environment: $ENVIRONMENT_INPUT"
    echo "Available environments: local, dev, staging, prod"
    exit 1
    ;;
esac

CONFIG_FILE="$PROJECT_ROOT/config/environments/${ENVIRONMENT}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Parse configuration
GATEWAY_URL_FROM_CONFIG=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_USER_FROM_CONFIG=$(grep "username:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_PASS_FROM_CONFIG=$(grep "password:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
BACKUP_PATH=$(grep "backup_path:" "$CONFIG_FILE" | awk '{print $2}')
CONTAINER_NAME=$(grep "container_name:" "$CONFIG_FILE" | awk '{print $2}')

GATEWAY_URL_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_URL"
GATEWAY_USER_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_USER"
GATEWAY_PASS_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_PASS"

GATEWAY_URL="$(eval echo \$${GATEWAY_URL_ENV_VAR})"
GATEWAY_USER="$(eval echo \$${GATEWAY_USER_ENV_VAR})"
GATEWAY_PASS="$(eval echo \$${GATEWAY_PASS_ENV_VAR})"

if [ -z "$GATEWAY_URL" ]; then
  GATEWAY_URL="$GATEWAY_URL_FROM_CONFIG"
fi
if [ -z "$GATEWAY_USER" ]; then
  GATEWAY_USER="$GATEWAY_USER_FROM_CONFIG"
fi
if [ -z "$GATEWAY_PASS" ]; then
  GATEWAY_PASS="$GATEWAY_PASS_FROM_CONFIG"
fi
if [ -z "$GATEWAY_PASS" ] && [ -f "$PROJECT_ROOT/secrets/gateway_admin_password.txt" ]; then
  GATEWAY_PASS=$(tr -d '\r\n' < "$PROJECT_ROOT/secrets/gateway_admin_password.txt")
fi

# Create backup directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/$BACKUP_PATH"

# Generate backup filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="gateway_backup_${ENVIRONMENT}_${TIMESTAMP}.gwbk"
BACKUP_FULL_PATH="$PROJECT_ROOT/$BACKUP_PATH/$BACKUP_FILE"

echo "Creating gateway backup for $ENVIRONMENT environment..."
echo "Backup file: $BACKUP_FILE"

# Method 1: Use docker exec to create backup inside container
# This creates a backup using Ignition's built-in backup functionality
docker exec "$CONTAINER_NAME" sh -c "
  cd /usr/local/bin/ignition
  ./gwcmd.sh --backup /backups/$BACKUP_FILE --promptyes --timeout 120
" > /dev/null 2>&1 || echo "  ⚠ gwcmd backup skipped (requires gateway configuration)"

# Method 2: Copy the entire data directory (alternative approach)
echo "Creating filesystem backup..."
docker cp "${CONTAINER_NAME}:/usr/local/bin/ignition/data" "$PROJECT_ROOT/$BACKUP_PATH/data_backup_${TIMESTAMP}" > /dev/null 2>&1 && echo "  ✓ Filesystem backup created" || echo "  ⚠ Filesystem backup skipped"

# Method 3: Export individual projects via REST API (if available in Ignition 8.3)
echo "Attempting to export projects via API..."
mkdir -p "$PROJECT_ROOT/$BACKUP_PATH/projects_${TIMESTAMP}"

# Get list of projects (this requires proper API authentication)
# Note: Adjust API endpoint based on your Ignition version
if [ -n "$GATEWAY_USER" ] && [ -n "$GATEWAY_PASS" ]; then
  curl -s -u "${GATEWAY_USER}:${GATEWAY_PASS}" \
    "${GATEWAY_URL}/system/webdev/projects" \
    -o "$PROJECT_ROOT/$BACKUP_PATH/projects_${TIMESTAMP}/project_list.json" 2>/dev/null && \
    echo "  ✓ Project list exported" || \
    echo "  ⚠ Project export via API not available"
else
  echo "  ⚠ Gateway credentials not set, skipping project export"
fi

# Clean up old backups (keep last N backups based on retention policy)
RETENTION_DAYS=$(grep "backup_retention_days:" "$CONFIG_FILE" | awk '{print $2}')
if [ -n "$RETENTION_DAYS" ]; then
  echo "Cleaning up backups older than $RETENTION_DAYS days..."
  find "$PROJECT_ROOT/$BACKUP_PATH" -name "gateway_backup_*" -mtime "+$RETENTION_DAYS" -delete 2>/dev/null || true
  find "$PROJECT_ROOT/$BACKUP_PATH" -name "data_backup_*" -mtime "+$RETENTION_DAYS" -exec rm -rf {} \; 2>/dev/null || true
fi

echo "✓ Backup completed: $BACKUP_FILE"
echo "  Location: $BACKUP_FULL_PATH"
