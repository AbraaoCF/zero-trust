# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	 		OPA Policy with Zero Trust Approach 		  #
# 			 	Fine Grained Access Control				  #
# 			Author: Abraão Caiana de Freitas   		 	  #
#				(github.com/AbraaoCF) 				  	  #
# # # # # # # # # # # # # # # # # # # # # # # # # # # #	# #
# This policy is responsible for the fine-grained access  #
# control of the API Gateway. It is responsible for       #
# authorizing the requests based on the path and the      #
# client's SPIFFE ID.									  #
#														  #
# # # # # # # # # # # # # # # # # # # # # # # # # # # #	# #

package envoy.authz

import rego.v1

route := http_request.path

# Auth
allow_path := endpoint if {
	glob.match(`/service/rest/auth`, ["/"], route)
	endpoint := `/service/rest/auth`
}

# Building
allow_path := endpoint if {
	glob.match(`/service/rest/building/*`, ["/"], route)
	check_id_building
	endpoint := `/service/rest/building/*`
}

allow_path := endpoint if {
	glob.match(`/service/rest/building/*/sensors`, ["/"], route)
	check_id_building
	endpoint := `/service/rest/building/*/sensors`
}

allow_path := endpoint if {
	glob.match(`/service/rest/building/*/demands`, ["/"], route)
	check_id_building
	endpoint := `/service/rest/building/*/demands`
}

# Consumption
allow_path := endpoint if {
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

# Sensor
allow_path := endpoint if {
	glob.match(`/service/rest/sensors`, ["/"], route)
	check_id_sensor
	endpoint := `/service/rest/sensors`
}

allow_path := endpoint if {
	glob.match(`/service/rest/sensor/*`, ["/"], route)
	check_id_sensor
	endpoint := `/service/rest/sensor/*`
}

allow_path := endpoint if {
	glob.match(`/service/rest/consumptionHistory`, ["/"], route)
	check_id_sensor
	endpoint := `/service/rest/consumptionHistory`
}

# Statistics
allow_path := endpoint if {
	glob.match(`/service/rest/building/*/statistics`, ["/"], route)
	check_id_statistics
	endpoint := `/service/rest/building/*/statistics`
}

allow_path := endpoint if {
	glob.match(`/service/rest/sensor/*/statistics`, ["/"], route)
	check_id_statistics
	endpoint := `/service/rest/sensor/*/statistics`
}

allow_path := endpoint if {
	glob.match(`/service/rest/building/*/statisticsStatus`, ["/"], route)
	check_id_statistics
	endpoint := `/service/rest/building/*/statisticsStatus`
}

allow_path := endpoint if {
	glob.match(`/service/rest/building/*/periodStatisticsStatus`, ["/"], route)
	check_id_statistics
	endpoint := `/service/rest/building/*/periodStatisticsStatus`
}

allow_path := endpoint if {
	glob.match(`/service/rest/building/*/statistics/alwayson`, ["/"], route)
	check_id_statistics
	endpoint := `/service/rest/building/*/statistics/alwayson`
}

# User
allow_path := endpoint if {
	glob.match(`/service/rest/user/*/sensors`, ["/"], route)
	check_id_user
	endpoint := `/service/rest/user/*/sensors`
}

svc_spiffe_id := client_id if {
	client_id := input.attributes.source.principal
}

svc_spiffe_id := client_id if {
	not	input.attributes.source.principal
	client_id := "unauthenticated"
}

check_id_building if {
	svc_spiffe_id in data.building_svc
}

check_id_unsupported if {
	svc_spiffe_id in data.unsupported_svc
}

check_id_consumption if {
	svc_spiffe_id in data.consumption_svc
}

check_id_sensor if {
	svc_spiffe_id in data.sensor_svc
}

check_id_statistics if {
	svc_spiffe_id in data.statistics_svc
}

check_id_user if {
	svc_spiffe_id in data.user_svc
}
