FROM openpolicyagent/opa:latest-envoy

WORKDIR /app

CMD ["run", "-s",\
     "--set=decision_logs.console=true", \
     "policies", \
     "--log-level", "debug", \
     "--log-format", "json-pretty", \
     "--tls-cert-file", "tls/server-cert.pem", \
     "--tls-private-key-file", "tls/server-key.pem", \
     "--tls-ca-cert-file", "tls/ca.pem", \
     "--authentication=tls", \
     "-a", ":8181" , \
     "--set=plugins.envoy_ext_authz_grpc.path=authz/allow", \
     "--set=plugins.envoy_ext_authz_grpc.addr=:9002"]