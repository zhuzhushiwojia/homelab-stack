#!/bin/bash
set -e

# Function to create database and user
create_db_and_user() {
    local db_name=$1
    local db_user=$2
    local db_password=$3
    
    echo "Creating database '$db_name' and user '$db_user'..."
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE USER $db_user WITH PASSWORD '$db_password';
        CREATE DATABASE $db_name;
        GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
        ALTER DATABASE $db_name OWNER TO $db_user;
EOSQL
    
    echo "Database '$db_name' and user '$db_user' created successfully."
}

# Create Gitea database and user
create_db_and_user "gitea" "gitea" "$GITEA_DB_PASSWORD"

# Create Vaultwarden database and user
create_db_and_user "vaultwarden" "vaultwarden" "$VAULTWARDEN_DB_PASSWORD"

# Create Outline database and user
create_db_and_user "outline" "outline" "$OUTLINE_DB_PASSWORD"

echo "All databases and users created successfully."