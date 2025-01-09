# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	 		OPA Policy with Zero Trust Approach 		 
# 					  Rate Limiting 				  	 
# 			Author: Abraão Caiana de Freitas   		 	 
#					(github.com/AbraaoCF) 		    	 
# # # # # # # # # # # # # # # # # # # # # # # # # # # #	#
#  Features of this policy are:				             
#														 
#  - Rate Limiting with Budget (enabled by default)		 
#														 
#  - Night Budget Evaluation (disabled by default) 	  	 
# 		To enable, the specific project configuration    
#		must set the night_budget attribute != 0		 
#														 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #

package authz

import rego.v1

http_request := input.attributes.request.http

rate_limit_user := data.rate_limits_config.user_max_requests_per_window

rate_limit_endpoint := data.rate_limits_config.endpoint_max_requests_per_window

rate_limit_user_endpoint := data.rate_limits_config.user_endpoint_requests_per_window

environment_variables := data.environment_variables

project_config := map_project_config(data.projects_config, svc_principal)

script := `
local set1 = KEYS[1]
local start = KEYS[2]

redis.call("ZREMRANGEBYLEX", set1, "[0", "(" .. start)

local set1_members = redis.call("ZRANGE", set1, 0, -1, "WITHSCORES")

local set1_sum = 0
for i = 2, #set1_members, 2 do
    set1_sum = set1_sum + tonumber(set1_members[i])
end

return set1_sum
`

map_project_config(configs, project) := config if {
	config := configs[project]
} else := config if {
	config := configs["default"]
}

now := time.now_ns() / 1000000000

window_start := now - data.rate_limits_config.time_window_seconds

user_budget := budget if {
	inside_working_hours
	budget := project_config.budget
}

user_budget := budget if {
	not inside_working_hours
	budget := project_config.night_budget
}

inside_working_hours if {
	[hour, _, _] := time.clock(time.now_ns())
	hour >= environment_variables.starting_working_hours
	hour <= environment_variables.ending_working_hours
}

default allow := false

allow := response if {
	svc_principal == "spiffe://acme.com/admin"
	response := {
		"allowed": true,
		"headers": {"x-ext-authz-check": "allowed"},
		"id": svc_principal,
		"request_costs": -1,
		"budget_left": -1,
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
		"request_costs": 0,
		"budget_left": -1,
	}
}

allow := response if {
	http_request.method == "GET"
	endpoint := allow_path
	user := svc_principal
	not user in data.anomalies.users
	request_info := process_request_budget(user, endpoint)
    response = choose_response(request_info, user)
}


choose_response(request_info, user) = response if {
    not request_info.exceed_budget
    response := {
        "allowed": true,
        "headers": {"x-ext-authz-check": "allowed"},
        "id": user,
        "request_costs": request_info.cost_request,
        "budget_left": request_info.budget_left,
    }
	log_request_budget(request_info.user_id_budget, now, request_info.cost_request)
}


choose_response(request_info, user) = response if {
    request_info.exceed_budget
    response := {
        "allowed": false,
        "http_status": 429,
        "headers": {"x-ext-authz-check": "denied", "x-ext-authz-error": "Budget exceeded"},
        "id": user,
        "request_costs": request_info.cost_request,
        "budget_left": request_info.budget_left,
    }
}


process_request_budget(user, endpoint) = response if {
    user_id_budget := sprintf("%s/budget", [user])
    cost_logs := request_logs_cost(user_id_budget, user_budget, window_start)
    cost_request := data.cost_endpoints[endpoint]
    response := {
        "user_id_budget": user_id_budget,
        "cost_logs": cost_logs,
        "cost_request": cost_request,
        "budget_left": user_budget - (cost_logs + cost_request),
        "exceed_budget": cost_logs + cost_request > user_budget
    }
}

ca_cert := "tls/ca.crt"

client_cert := "tls/opa.crt"

client_key := "tls/opa.key"

request_logs_cost(id, budget, window_start) := total_cost if {
	encoded_id := urlquery.encode(id)
	encoded_script := urlquery.encode(script)
	redisl := http.send({
		"method": "GET",
		"url": sprintf("https://state-storage.zt.local:7379/EVAL/%s/2/%s/%.5f", [encoded_script, encoded_id, window_start]),
		"tls_ca_cert_file": ca_cert,
		"tls_client_cert_file": client_cert,
		"tls_client_key_file": client_key,
	})
	total_cost := to_number(redisl.body.EVAL)
}


log_request_budget(id, timestamp, value) if {
	http.send({
		"method": "GET",
		"url": sprintf("https://state-storage.zt.local:7379/ZINCRBY/%s/%v/%.5f", [urlquery.encode(id), value, timestamp]),
		"headers": {"Content-Type": "application/json"},
		"tls_ca_cert_file": ca_cert,
		"tls_client_cert_file": client_cert,
		"tls_client_key_file": client_key,
	})
}
