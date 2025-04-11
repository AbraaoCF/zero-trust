#	 		OPA Policy with Zero Trust Approach
# 			 	Fine Grained Access Control
# 			Author: Abraão Caiana de Freitas
#				(github.com/AbraaoCF)
# # # # # # # # # # # # # # # # # # # # # # # # # # # #	#
# This policy is responsible for the fine-grained access
# control of the API Gateway. It is responsible for
# authorizing the requests based on the path and the
# client's Principal ID.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # #	#

package authz

import rego.v1

# Assegurar que http_request já está definido no mesmo pacote
# route := http_request.path
route := input.attributes.request.http.path

# Pre-compile patterns for more efficient matching
# Maps exact patterns to endpoints for quick exact matches
exact_path_map := {
	"/service/rest/auth": "/service/rest/auth",
	"/items": "/items"
}

# Function to check if a path exists in the exact match map
is_exact_match(path) := endpoint if {
	endpoint := exact_path_map[path]
}

# Load Test - check exact match first
allow_path := endpoint if {
	endpoint := is_exact_match(route)
	endpoint == "/items"
	# Remover esta verificação para permitir acesso geral ao endpoint /items
	# check_id_load_test
}

# Auth - check exact match first
allow_path := endpoint if {
	endpoint := is_exact_match(route)
	endpoint == "/service/rest/auth"
}

# Only use glob matching for paths that really need wildcards
allow_path := endpoint if {
	not is_exact_match(route)
	glob.match(`/service/rest/building/*/demand/last`, ["/"], route)
	check_id_consumption
	endpoint := `/service/rest/building/*/demand/last`
}

allow_path := endpoint if {
	glob.match(`/service/rest/building/*/demand/last_n_minutes`, ["/"], route)
	check_id_consumption
	endpoint := `/service/rest/building/*/demand/last_n_minutes`
}

allow_path := endpoint if {
	glob.match(`/service/rest/building/*/consumption`, ["/"], route)
	check_id_consumption
	endpoint := `/service/rest/building/*/consumption`
}

allow_path := endpoint if {
	glob.match(`/service/rest/building/*/demandReport`, ["/"], route)
	check_id_consumption
	endpoint := `/service/rest/building/*/demandReport`
}

# Unsupported Media Type
allow_path := endpoint if {
	glob.match(`/service/rest/building/*/consumption/disaggregated`, ["/"], route)
	check_id_unsupported
	endpoint := `/service/rest/building/*/consumption/disaggregated`
}

# User
allow_path := endpoint if {
	glob.match(`/service/rest/user/*/sensors`, ["/"], route)
	check_id_user
	endpoint := `/service/rest/user/*/sensors`
}

svc_principal := client_id if {
	client_id := input.attributes.source.principal
}

svc_principal := client_id if {
	not input.attributes.source.principal
	client_id := "unauthenticated"
}

check_id_load_test if {
	svc_principal in data.load_test_svc
}

check_id_unsupported if {
	svc_principal in data.unsupported_svc
}

check_id_consumption if {
	svc_principal in data.consumption_svc
}

check_id_user if {
	svc_principal in data.user_svc
}
