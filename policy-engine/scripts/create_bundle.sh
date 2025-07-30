#!/bin/bash

set -e

# Create a bundle from source policies for better performance
echo "Creating policy bundle from source policies..."
mkdir -p /app/policies

# Use opa build to create an optimized bundle
opa build /app/policies_src/authz/policy.rego /app/policies_src/authz/policy_routes.rego -o /app/policies/bundle.tar.gz

# Extract the bundle
tar -xzf /app/policies/bundle.tar.gz -C /app/policies

# Copy data.json to the bundle directory 
cp /app/policies_src/data.json /app/policies/

# Remove the tar file after extraction
rm /app/policies/bundle.tar.gz

echo "Bundle created successfully!"

# Execute the command passed to this script
exec "$@" 