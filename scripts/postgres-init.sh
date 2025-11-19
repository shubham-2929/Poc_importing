#!/bin/bash
set -e

# PostgreSQL initialization script
# Creates environment-specific databases on first container startup
# This script runs automatically when mounted to /docker-entrypoint-initdb.d/

echo "Initializing environment databases..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create development database
    SELECT 'CREATE DATABASE ignition_dev'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ignition_dev')\gexec

    -- Create staging database
    SELECT 'CREATE DATABASE ignition_staging'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ignition_staging')\gexec

    -- Create production database
    SELECT 'CREATE DATABASE ignition_prod'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ignition_prod')\gexec

    -- List all databases
    \l
EOSQL

echo "Environment databases initialized successfully"
