FROM openpolicyagent/opa:1.1.0-envoy

WORKDIR /app

CMD ["run", "-s",\
     "--set=decision_logs.console=true", \
     "policies", \
     "--log-level", "debug", \
     "--log-format", "json-pretty", \
     "--tls-cert-file", "tls/opa.crt", \
     "--tls-private-key-file", "tls/opa.key", \
     "--tls-ca-cert-file", "tls/ca.crt", \
     "--authentication=tls", \
     "--set=plugins.envoy_ext_authz_grpc.path=authz/allow", \
     "--set=plugins.envoy_ext_authz_grpc.addr=:9002"]