#!/bin/bash
# Run Jython tests via WebDev API
# Usage: ./scripts/run-tests.sh [environment]
# Example: ./scripts/run-tests.sh local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT_INPUT="${1:-local}"

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

GATEWAY_URL_FROM_CONFIG=$(grep "url:" "$CONFIG_FILE" | head -1 | awk '{print $2}')
GATEWAY_URL_ENV_VAR="${ENV_VAR_PREFIX}_GATEWAY_URL"
GATEWAY_URL="$(eval echo \$${GATEWAY_URL_ENV_VAR})"

if [ -z "$GATEWAY_URL" ]; then
  GATEWAY_URL="$GATEWAY_URL_FROM_CONFIG"
fi

echo "Running tests on $ENVIRONMENT..."
echo ""

RESPONSE=$(curl -s "${GATEWAY_URL}/system/webdev/TestProject/api/test")

echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('results', 'No results'))
except:
    print(sys.stdin.read())
"
