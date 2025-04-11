# CA
openssl ecparam -genkey -name prime256v1 -noout -out ca.key
openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.crt -config ca.cnf

# OpenSearch
openssl genrsa -out opensearch.key 4096
openssl req -new -key opensearch.key -out opensearch.csr -config opensearch.cnf
openssl x509 -req -in opensearch.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out opensearch.crt -days 365 -sha256 -extensions v3_req -extfile opensearch.cnf

# Opa
openssl genrsa -out opa.key 4096
openssl req -new -key opa.key -out opa.csr -config opa.cnf
openssl x509 -req -in opa.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out opa.crt -days 365 -sha256 -extensions v3_req -extfile opa.cnf

# Envoy - Service
openssl genrsa -out envoy-service.key 4096
openssl req -new -key envoy-service.key -out envoy-service.csr -config envoy-service.cnf
openssl x509 -req -in envoy-service.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out envoy-service.crt -days 365 -sha256 -extensions v3_req -extfile envoy-service.cnf

# Envoy - State Storage
openssl genrsa -out envoy-ss.key 4096
openssl req -new -key envoy-ss.key -out envoy-ss.csr -config envoy-ss.cnf
openssl x509 -req -in envoy-ss.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out envoy-ss.crt -days 365 -sha256 -extensions v3_req -extfile envoy-ss.cnf

# Normal
openssl genrsa -out normal.key 4096
openssl req -new -key normal.key -out normal.csr -config normal.cnf
openssl x509 -req -in normal.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out normal.crt -days 365 -sha256 -extensions v3_req -extfile normal.cnf

# Anomalous
openssl genrsa -out anomalous.key 4096
openssl req -new -key anomalous.key -out anomalous.csr -config anomalous.cnf
openssl x509 -req -in anomalous.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out anomalous.crt -days 365 -sha256 -extensions v3_req -extfile anomalous.cnf

# Service 
openssl genrsa -out service.key 4096
openssl req -new -key service.key -out service.csr -config service.cnf
openssl x509 -req -in service.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out service.crt -days 365 -sha256 -extensions v3_req -extfile service.cnf

# OPAL server keys for authentication
echo "Generating OPAL server RSA keys for authentication..."
ssh-keygen -t rsa -b 4096 -m pem -f opal_auth -N "" << EOF

EOF

# Convert the OPAL private key format for docker-compose (replace newlines with underscores)
echo "OPAL_AUTH_PRIVATE_KEY=$(cat opal_auth | tr '\n' '_')" > opal_keys.env
echo "OPAL_AUTH_PUBLIC_KEY=$(cat opal_auth.pub)" >> opal_keys.env
echo "OPAL keys generated and saved to opal_keys.env"

