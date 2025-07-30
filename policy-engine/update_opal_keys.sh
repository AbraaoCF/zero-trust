#!/bin/bash

# Check if opal_keys.env exists
if [ ! -f "../commons/certs/opal_keys.env" ]; then
    echo "Error: opal_keys.env not found. Run create_certs.sh first."
    exit 1
fi

# Source the environment variables from opal_keys.env
source "../commons/certs/opal_keys.env"

# Update docker-compose.yaml with the keys
sed -i "s|OPAL_AUTH_PRIVATE_KEY=YOUR_PRIVATE_KEY_CONTENT_HERE|OPAL_AUTH_PRIVATE_KEY=$OPAL_AUTH_PRIVATE_KEY|g" docker-compose.yaml
sed -i "s|OPAL_AUTH_PUBLIC_KEY=YOUR_PUBLIC_KEY_CONTENT_HERE|OPAL_AUTH_PUBLIC_KEY=$OPAL_AUTH_PUBLIC_KEY|g" docker-compose.yaml

echo "Docker compose file updated with OPAL authentication keys."
echo "You can now restart the OPAL services with: docker-compose down && docker-compose up -d" 