#			OPA Policy with Zero Trust Approach
#					Rate Limiting
#			Author: Abraão Caiana de Freitas
#				(github.com/AbraaoCF)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#  Features of this policy are:
#
#  - Rate Limiting with Quotas (enabled by default)
#
#  - Night Quotas Evaluation (disabled by default)
#    To enable, the specific project configuration
#    must set the afterHoursQuotas attribute != 0
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #

package authz


http_request := input.attributes.request.http

rate_limit_user := data.rate_limits_config.user_max_requests_per_window

rate_limit_endpoint := data.rate_limits_config.endpoint_max_requests_per_window

rate_limit_user_endpoint := data.rate_limits_config.user_endpoint_requests_per_window

environment_variables := data.environment_variables

project_config := map_project_config(data.projects_config, svc_principal)

map_project_config(configs, project) := config if {
		config := configs[project]
} else := config if {
        config := configs["default"]
}

now := time.now_ns() / 1000000000

window_start := now - data.rate_limits_config.time_window_seconds

user_quotas := quotas if {
        inside_working_hours
        quotas := project_config.quotas
}

user_quotas := quotas if {
        not inside_working_hours
        quotas := project_config.afterHoursQuotas
}

inside_working_hours if {
    [hour, _, _] := time.clock(time.now_ns())
    day := time.weekday(time.now_ns())

    hour >= environment_variables.starting_working_hours
    hour <= environment_variables.ending_working_hours

    day >= 1
    day <= 5
}


default allow := false

allow := response if {
        svc_principal == "spiffe://acme.com/admin"
        response := {
                "allowed": true,
                "headers": {"x-ext-authz-check": "allowed"},
                "id": svc_principal,
        }
}

allow := response if {
        http_request.method == "GET"
        endpoint := allow_path
        endpoint in data.whitelisted_endpoints
        response := {
                "allowed": true,
                "headers": {"x-ext-authz-check": "allowed"},
                "id": svc_principal,
        }
}

allow := response if {
        http_request.method == "GET"
        endpoint := allow_path
        user := svc_principal
        not user in data.anomalies.users
        request_info := process_request_quotas(user, endpoint)
    response = choose_response(request_info, user)
}


choose_response(request_info, user) = response if {
    not request_info.exceed_quotas
    response := {
        "allowed": true,
        "headers": {"x-ext-authz-check": "allowed"},
        "id": user,
    }
        # log_request_quotas(request_info.user_id_quotas, now, request_info.cost_request)
}


choose_response(request_info, user) = response if {
    request_info.exceed_quotas
    response := {
        "allowed": false,
        "http_status": 429,
        "headers": {"x-ext-authz-check": "denied", "x-ext-authz-error": "Quotas exceeded"},
        "id": user,
    }
}


process_request_quotas(user, endpoint) = response if {
    user_id_quotas := sprintf("%s/quotas", [user])
    cost_logs := request_logs_cost(user_id_quotas, user_quotas, window_start, endpoint)
    cost_request := data.cost_endpoints[endpoint]
    response := {
        "user_id_quotas": user_id_quotas,
        "cost_logs": cost_logs,
        "cost_request": cost_request,
    }
}

ca_cert := "tls/ca.crt"

client_cert := "tls/opa.crt"

client_key := "tls/opa.key"

request_logs_cost(id, quotas, window_start, endpoint) := total_cost if {
        encoded_id := urlquery.encode(id)
        cost_request := data.cost_endpoints[endpoint]
                storage := http.send({
                "method": "GET",
                "url": sprintf("https://state-storage.zt.local:7378/LRANGE/%s/0/%v", [urlquery.encode(id), quotas]),
                "headers": {
                        "Content-Type": "application/json",
                        "x-timestamp": sprintf("%f", [window_start]),
                },
                "tls_ca_cert_file": ca_cert,
                "tls_client_cert_file": client_cert,
                "tls_client_key_file": client_key,
        })
        total_cost := to_number(storage.body)
}


# log_request_quotas(id, timestamp, value) if {
#       http.send({
#               "method": "GET",
#               "url": sprintf("https://state-storage.zt.local:7379/ZINCRBY/%s/%v/%.5f", [urlquery.encode(id), value, timestamp]),
#               "headers": {"Content-Type": "application/json"},
#               "tls_ca_cert_file": ca_cert,
#               "tls_client_cert_file": client_cert,
#               "tls_client_key_file": client_key,
#       })
# }