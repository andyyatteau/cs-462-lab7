ruleset manage_fleet {
	meta {
		name "Fleet Manager"
		description <<
Lab 7
>>
		author "Andy Yatteau"
		logging on
		shares __testing, fleet, vehicles, show_children
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
				"attrs": { "rid": "trip_store", "vehicle_id": vehicle_id } } )
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
}
