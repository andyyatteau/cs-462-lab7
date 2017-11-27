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
  	}
  	rule create_vehicle {
		select when car new_vehicle
		pre {
			vehicle_id = event:attr("vehicle_id")
			exists = ent:vehicles >< vehicle_id
		}
		if not exists
		then
			noop()
		fired {
			raise pico event "new_child_request"
				attributes {
					"dname": nameFromId(vehicle_id),
					"color": "#87fa97",
					"vehicle_id": vehicle_id
				}
		}	
	}
	rule vehicle_already_exists {
		select when car new_vehicle
        pre {
            vehicle_id = event:attr("vehicle_id")
            exists = ent:vehicles >< vehicle_id
        }
        if exists then
	    	send_directive("vehicle_ready", {"vehicle_id":vehicle_id})
	}
	rule pico_child_initialized {
		select when pico child_initialized
		pre {
			the_vehicle = event:attr("new_child")
			vehicle_id = event:attr("rs_attrs") {"vehicle_id"};
		}
		if section_id.klog("found vehicle_id")
		then
			noop()
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
			child_to_delete = childFromId(vehicle_id)
		}
		if exists then
			send_directive("vehicle_deleted", {"vehicle_id":vehicle_id})
		fired {
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
