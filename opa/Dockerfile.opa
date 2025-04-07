FROM openpolicyagent/opa:1.3.0-envoy

WORKDIR /app

# Configure OPA with necessary settings for OPAL integration
CMD ["run", "-s", \
     "--server", \
     "--log-level", "info", \
     "--log-format", "json-pretty", \
     "--addr", "0.0.0.0:8181", \
     "--tls-cert-file", "tls/opa.crt", \
     "--tls-private-key-file", "tls/opa.key", \
     "--tls-ca-cert-file", "tls/ca.crt", \
     "--authentication=tls", \
     "--set=decision_logs.console=true", \
     "--set=plugins.envoy_ext_authz_grpc.path=authz/allow", \
     "--set=plugins.envoy_ext_authz_grpc.addr=:9002"]