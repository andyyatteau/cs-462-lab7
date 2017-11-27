ruleset manage_fleet {
	meta {
		name "Fleet Manager"
		description <<
Lab 7
>>
		author "Andy Yatteau"
		logging on
		shares __testing, fleet, vehicles, show_children, get_trips, five_latest
		use module io.picolabs.pico alias wrangler
		use module Subscriptions
  	}
  	global {
  		__testing = { 
			"queries": [ 
				{ 
					"name": "__testing" 
				},
				{
					"name": "fleet"
				},
				{
					"name": "vehicles"
				},
				{
					"name": "show_children"
				},
				{
					"name": "get_trips"
				},
				{
					"name": "five_latest"
				}
			],
                  	"events": [
				{
					"domain": "car",
					"type": "new_vehicle",
					"attrs": [
						"vehicle_id"
					]
				},
				{
					"domain": "car",
					"type": "unneeded_vehicle",
					"attrs": [
						"vehicle_id"
					]
				},
				{
	                "domain": "car",
	                "type": "request_report"
	            },
	            {
	                "domain": "car",
	                "type": "reports_empty"
	            }
	 		] 
		}
  		fleet = function() {
			ent:vehicles
		}
  		vehicles = function() {
			Subscriptions:getSubscriptions()
		}
		show_children = function() {
			wrangler:children()
		}
		childFromID = function(vehicle_id) {
			ent:vehicles[vehicle_id]
		}
		subscriptionFromID = function(vehicle_id) {
      		"vehicle_" + vehicle_id
	    }
	    subscriptionName = function(vehicle_id) {
	    	"car:" + subscriptionFromID(vehicle_id)
	    }
	    url = function(subscription) {
    		"http://localhost:8080/sky/cloud/" + subscription{"attributes"}{"subscriber_eci"} + "/trip_store_multiple/trips"
    	}
    	get_trips = function() {
	    	Subscriptions:getSubscriptions().filter(function(x) {x{"attributes"}{"subscriber_role"} == "vehicle"}).map(function(x) {
	        todecode = http:get(url(x));
	        todecode{"content"}.decode()
	    	})
    	}
    	five_latest = function() {
	    	length = ent:reports.values().length();
	    	(length > 5) => ent:reports.values().slice(length - 5, length - 1) | ent:reports.values()
	    }
  	}
  	rule create_vehicle {
    	select when car new_vehicle
    	pre {
    		vehicle_id = event:attr("vehicle_id")
    		exists = ent:vehicles >< vehicle_id
    		eci = meta:eci
    	}
	    if exists then
	    	send_directive("vehicle_ready", {"vehicle_id":vehicle_id})
	    fired {
	    } else {
    		raise pico event "new_child_request"
        		attributes { "dname": subscriptionFromID(vehicle_id),
                    "color": "#87fa97",
                    "vehicle_id": vehicle_id }
                }
    }
	rule pico_child_initialized {
		select when pico child_initialized
		pre {
			the_vehicle = event:attr("new_child")
			vehicle_id = event:attr("rs_attrs") {"vehicle_id"};
			eci = meta:eci
		}
		every {
			event:send({ "eci": eci, "eid": "subscription",
			    "domain": "wrangler", "type": "subscription",
			    "attrs": { "name": subscriptionFromID(vehicle_id),
	            	"name_space": "car",
	                "my_role": "fleet",
	                "subscriber_role": "vehicle",
	                "channel_type": "subscription",
	                "subscriber_eci": the_vehicle.eci} } )
			event:send({ "eci": the_vehicle.eci, "eid": "install-ruleset",
				"domain": "pico", "type": "new_ruleset",
				"attrs": { "rid": "Subscriptions", "vehicle_id": vehicle_id } } )
			event:send({ "eci": the_vehicle.eci, "eid": "install-ruleset",
				"domain": "pico", "type": "new_ruleset",
				"attrs": { "rid": "track_trips2", "vehicle_id": vehicle_id } } )
			event:send({ "eci": the_vehicle.eci, "eid": "install-ruleset",
				"domain": "pico", "type": "new_ruleset",
				"attrs": { "rid": "trip_store_multiple", "vehicle_id": vehicle_id } } )
		}
		fired {
		    ent:vehicles := ent:vehicles.defaultsTo({});
		    ent:vehicles{[vehicle_id]} := the_vehicle
		}
	}
	rule delete_vehicle {
		select when car unneeded_vehicle
		pre {
			vehicle_id = event:attr("vehicle_id")
			exists = ent:vehicles >< vehicle_id
			eci = meta:eci
			child_to_delete = childFromID(vehicle_id)
		}
		if exists then
			send_directive("vehicle_deleted", {"vehicle_id":vehicle_id})
		fired {
			raise wrangler event "subscription_cancellation"
        		attributes {"subscription_name": subscriptionName(vehicle_id)};
			raise pico event "delete_child_request"
				attributes child_to_delete;
			ent:vehicles{[vehicle_id]} := null
		}
	}
	rule collection_empty {
		select when collection empty
		always {
			ent:vehicles := {}
		}
	}
	rule request_report {
	    select when car request_report
	    pre {
	    	rcn = time:now().replace(".", ":")
	    	eci = meta:eci
	    }
	    fired {
	    	raise explicit event "generate_report"
	        	attributes {"rcn": rcn, "eci": eci}
	    }
	}
	rule generate_report {
	    select when explicit generate_report
	    foreach Subscriptions:getSubscriptions() setting(subscription)
	    	pre {
	    		eci = event:attr("eci")
	        	rcn = event:attr("rcn")
	    	}
	    	if subscription{"attributes"}{"subscriber_role"} == "vehicle" then
	    		event:send({ "eci": subscription{"attributes"}{"subscriber_eci"}, "eid": "generate_report", "domain": "car", "type": "generate_report", "attrs": {"rcn": rcn, "sender_eci": eci, "vehicle_id": subscription{"name"}}})
	}
	rule receive_report {
	    select when car send_report
	    pre {
	    	rcn = event:attr("rcn")
	    	vehicle_id = event:attr("vehicle_id")
	    	trips = event:attr("trips")
	    }
	    always {
	    	ent:reports := ent:reports.defaultsTo({});
	    	ent:reports{[rcn, "Responding vehicles"]} := ent:vehicles.length();
	    	ent:reports{[rcn, vehicle_id]} := trips
	    }
	}
	rule reports_empty {
	    select when car reports_empty
	    always {
	    	ent:reports := {};
	    }
	}
}
