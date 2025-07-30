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

import rego.v1

http_request := input.attributes.request.http

environment_variables := data.environment_variables

project_config := map_project_config(data.projects_config, svc_principal)

map_project_config(configs, project) := config if {
	config := configs[project]
} else := config if {
	config := configs["default"]
}

now_ns := time.now_ns()

now := now_ns / 1000000000

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
	[hour, _, _] := time.clock(now_ns)

	hour >= environment_variables.starting_working_hours
	hour <= environment_variables.ending_working_hours

	day := time.weekday(now_ns)
	not (day in environment_variables.weekend_days)
}

default allow := false

allow := response if {
	# Quick admin check for immediate approval 
	svc_principal == "spiffe://acme.com/admin"
	response := {
		"allowed": true,
		"headers": {"x-ext-authz-check": "allowed"},
		"id": svc_principal,
	}
}

# Quick check for whitelisted endpoints
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

# Quick check for anomalies - deny fast
allow := response if {
	user := svc_principal
	user in data.anomalies.users
	response := {
		"allowed": false,
		"http_status": 403,
		"headers": {"x-ext-authz-check": "denied", "x-ext-authz-error": "User in anomalies list"},
		"id": user,
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

choose_response(request_info, user) := response if {
	not request_info.exceed_quotas
	response := {
		"allowed": true,
		"headers": {"x-ext-authz-check": "allowed"},
		"id": user,
		"response" : request_info
	}
}

choose_response(request_info, user) := response if {
	request_info.exceed_quotas
	response := {
		"allowed": false,
		"http_status": 429,
		"headers": {"x-ext-authz-check": "denied", "x-ext-authz-error": "Quotas exceeded"},
		"id": user,
		"response" : request_info
	}
}

# Check if usage tracker data is fresh (updated within last 5 minutes)
usage_data_is_fresh if {
    last_updated := data.usage_tracker.last_updated
    time_diff := now - last_updated
    time_diff < 300  # 5 minutes = 300 seconds
}

# Instead of Redis, we'll store and retrieve rate limiting data through OPAL
# OPAL will automatically handle the persistence and caching
process_request_quotas(user, endpoint) := response if {
    # First check if usage data is fresh
    usage_data_is_fresh
    
    # Get current usage cost or default to 0 if not found
    current_usage := object.get(data.usage_tracker.users, [user, "cost"], 0)
    # Get the cost of this endpoint
    cost_request := data.cost_endpoints[endpoint]

    
    # Check if user exceeds quotas
    new_cost := current_usage + cost_request
    
    # Record this usage for future requests (OPAL will update this)
    # Usage data will be stored in data.usage_tracker by OPAL client
    
    response := {
        "user_id": user,
        "endpoint": endpoint,
        "current_usage": current_usage,
        "cost_request": cost_request,
        "new_cost": new_cost,
        "quotas": user_quotas,
        "exceed_quotas": new_cost > user_quotas
    }
}

# If usage data is not fresh (service might be down), allow the request but flag it
process_request_quotas(user, endpoint) := response if {
    not usage_data_is_fresh
    
    # Get the cost of this endpoint
    cost_request := data.cost_endpoints[endpoint]
    
    response := {
        "user_id": user,
        "endpoint": endpoint,
        "current_usage": 0,  # Default to 0 since data is stale
        "cost_request": cost_request,
        "new_cost": cost_request,
        "quotas": user_quotas,
        "exceed_quotas": false,  # Don't block if usage data is stale
        "data_stale": true
    }
}

# We'll track this usage update via the decision log
# OPAL client can consume the decision logs and update the usage data
