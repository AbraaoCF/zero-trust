# CA
openssl ecparam -genkey -name prime256v1 -noout -out ca.key
openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.crt -config ca.cnf
#openssl x509 -in ca.crt -text -noout

# OpenSearch
openssl genrsa -out opensearch.key 4096
openssl req -new -key opensearch.key -out opensearch.csr -config opensearch.cnf
openssl x509 -req -in opensearch.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out opensearch.crt -days 365 -sha256 -extensions v3_req -extfile opensearch.cnf
#openssl x509 -in opensearch.crt -text -noout

# Opa
openssl genrsa -out opa.key 4096
openssl req -new -key opa.key -out opa.csr -config opa.cnf
openssl x509 -req -in opa.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out opa.crt -days 365 -sha256 -extensions v3_req -extfile opa.cnf
#openssl x509 -in opa.crt -text -noout

# Envoy
openssl genrsa -out envoy.key 4096
openssl req -new -key envoy.key -out envoy.csr -config envoy.cnf
openssl x509 -req -in envoy.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out envoy.crt -days 365 -sha256 -extensions v3_req -extfile envoy.cnf
#openssl x509 -in envoy.crt -text -noout

# Normal
openssl genrsa -out normal.key 4096
openssl req -new -key normal.key -out normal.csr -config normal.cnf
openssl x509 -req -in normal.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out normal.crt -days 365 -sha256 -extensions v3_req -extfile normal.cnf
#openssl x509 -in normal.crt -text -noout

# Anomalous
openssl genrsa -out anomalous.key 4096
openssl req -new -key anomalous.key -out anomalous.csr -config anomalous.cnf
openssl x509 -req -in anomalous.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out anomalous.crt -days 365 -sha256 -extensions v3_req -extfile anomalous.cnf
#openssl x509 -in anomalous.crt -text -noout
