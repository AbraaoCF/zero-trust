# Certs

To ensure secure communication between components, TLS is implemented where necessary. Therefore, the certificates for the CA and other components must be created beforehand. We will walk through each step.

## Prerequisites

Before you begin, ensure you have `openssl` installed. If not, install it using:

```bash
sudo apt-get update
sudo apt-get install openssl
```

Verify the installation with:

```bash
openssl version
```

Then, navigate to this directory:

```bash
cd certs
```

## 1. Create the Certificate Authority (CA)

### 1.1. Generate the CA Private Key

Create a private key for the CA:

```bash
openssl ecparam -genkey -name prime256v1 -noout -out ca.key
```

### 1.2. Create the CA Self-Signed Certificate

Generate a self-signed certificate for the CA:

```bash
openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.crt -config ca.cnf
```

The **Common Name (CN)** field will be used as the trusted domain throughout the entire system. In this example, we will use `dhsg.com`, but feel free to change it to your domain on `ca.cnf`. 

Ensure the certificate was created correctly:

```bash
openssl x509 -in ca.crt -text -noout
```

## 2. Create a Certificate for OpenSearch

### 2.1. Generate the Private Key for OpenSearch

```bash
openssl genrsa -out opensearch.key 4096
```

### 2.2. Create the CSR (Certificate Signing Request)

See `opensearch.cnf` file before creating the CSR, and change where is needed.

```bash
openssl req -new -key opensearch.key -out opensearch.csr -config opensearch.cnf
```

### 2.3. Sign the CSR with the CA

```bash
openssl x509 -req -in opensearch.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out opensearch.crt -days 365 -sha256 -extensions v3_req -extfile opensearch.cnf
```

Ensure the certificate was created correctly:

```bash
openssl x509 -in opensearch.crt -text -noout
```

## 3. Create a Certificate for Open Policy Agent

### 3.1. Generate the Private Key for Open Policy Agent

```bash
openssl genrsa -out opa.key 4096
```

### 3.2. Create the CSR (Certificate Signing Request)

See `opa.cnf` file before creating the CSR, and change where is needed.

```bash
openssl req -new -key opa.key -out opa.csr -config opa.cnf
```

### 3.3. Sign the CSR with the CA

```bash
openssl x509 -req -in opa.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out opa.crt -days 365 -sha256 -extensions v3_req -extfile opa.cnf
```

Ensure the certificate was created correctly:

```bash
openssl x509 -in opa.crt -text -noout
```

## 4. Create a Certificate for Envoy Service

### 4.1. Generate the Private Key for Envoy Service

```bash
openssl genrsa -out envoy-service.key 4096
```

### 4.2. Create the CSR (Certificate Signing Request)

See `envoy-service.cnf` file before creating the CSR, and change where is needed.

```bash
openssl req -new -key envoy-service.key -out envoy-service.csr -config envoy-service.cnf
```

### 4.3. Sign the CSR with the CA

```bash
openssl x509 -req -in envoy-service.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out envoy-service.crt -days 365 -sha256 -extensions v3_req -extfile envoy-service.cnf
```

Ensure the certificate was created correctly:

```bash
openssl x509 -in envoy-service.crt -text -noout
```

## 5. Create a Certificate for Envoy State Storage

### 5.1. Generate the Private Key for Envoy State Storage

```bash
openssl genrsa -out envoy-ss.key 4096
```

### 5.2. Create the CSR (Certificate Signing Request)

See `envoy-ss.cnf` file before creating the CSR, and change where is needed.

```bash
openssl req -new -key envoy-ss.key -out envoy-ss.csr -config envoy-ss.cnf
```

### 5.3. Sign the CSR with the CA

```bash
openssl x509 -req -in envoy-ss.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out envoy-ss.crt -days 365 -sha256 -extensions v3_req -extfile envoy-ss.cnf
```

Ensure the certificate was created correctly:

```bash
openssl x509 -in envoy-ss.crt -text -noout
```

## 6. Create a Certificate for Normal

### 6.1. Generate the Private Key for Normal

```bash
openssl genrsa -out normal.key 4096
```

### 6.2. Create the CSR (Certificate Signing Request)

See `normal.cnf` file before creating the CSR, and change where is needed.

```bash
openssl req -new -key normal.key -out normal.csr -config normal.cnf
```

### 6.3. Sign the CSR with the CA

```bash
openssl x509 -req -in normal.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out normal.crt -days 365 -sha256 -extensions v3_req -extfile normal.cnf
```

Ensure the certificate was created correctly:

```bash
openssl x509 -in normal.crt -text -noout
```

## 7. Create a Certificate for Anomalous

### 7.1. Generate the Private Key for Anomalous

```bash
openssl genrsa -out anomalous.key 4096
```

### 7.2. Create the CSR (Certificate Signing Request)

See `anomalous.cnf` file before creating the CSR, and change where is needed.

```bash
openssl req -new -key anomalous.key -out anomalous.csr -config anomalous.cnf
```

### 7.3. Sign the CSR with the CA

```bash
openssl x509 -req -in anomalous.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out anomalous.crt -days 365 -sha256 -extensions v3_req -extfile anomalous.cnf
```

Ensure the certificate was created correctly:

```bash
openssl x509 -in anomalous.crt -text -noout
```

## 8. Create a Certificate for Anomalous

### 8.1. Generate the Private Key for Anomalous

```bash
openssl genrsa -out service.key 4096
```

### 8.2. Create the CSR (Certificate Signing Request)

See `service.cnf` file before creating the CSR, and change where is needed.

```bash
openssl req -new -key service.key -out service.csr -config service.cnf
```

### 8.3. Sign the CSR with the CA

```bash
openssl x509 -req -in service.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out service.crt -days 365 -sha256 -extensions v3_req -extfile service.cnf
```

Ensure the certificate was created correctly:

```bash
openssl x509 -in service.crt -text -noout
```
