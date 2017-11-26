ruleset manage_fleet {
	meta {
		name "Manage Fleet"
		description <<
Lab 7
>>
		author "Andy Yatteau"
		logging on
    	shares __testing, fleet, vehicles, vehicles_trips, show_children, latest_trips
		use module io.picolabs.pico alias wrangler
		use module io.picolabs.subscription alias Subscription
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
					"name": "vehicles_trips"
				},
				{
					"name": "show_children"
				},
                                {
                                        "name": "latest_trips"
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
					"domain": "fleet",
					"type": "report_requested"
				}
	 		] 
		}
		nameFromId = function(vehicle_id) {
			"Vehicle-" + vehicle_id + "-Pico"
		}
		childFromId = function(vehicle_id) {
			ent:vehicles[vehicle_id]
		}
		fleet = function() {
			ent:vehicles
		}
		vehicles = function() {
			Subscription:getSubscriptions()
		}
		vehicles_trips = function() {
			vehicles =  vehicles().filter(function(v, k) {(v{["attributes", "subscriber_role"]} == "vehicle"); });
			trips = vehicles.map(function(v, k) {
					child_eci = v{["attributes", "outbound_eci"]};
					child_trips(child_eci);
				});
			{
				"vehicles": vehicles.keys().length(),
				"responding": trips.keys().length(),
				"trips": trips
			};
		}

		child_trips = function(child_eci) {
			cloud_url = meta:host + "/sky/cloud/" + child_eci + "/track_trips/trips";
			response = http:get(cloud_url);
			
			status = response{"status_code"};
			error_info = {
			        "error": "sky cloud request was unsuccesful.",
			        "httpStatus": {
			        	"code": status,
			 	        "message": response{"status_line"}
        			}
    			};

			response_content = response{"content"}.decode();
			response_error = (response_content.typeof() == "Map" && response_content{"error"}) => response_content{"error"} | 0;
			response_error_str = (response_content.typeof() == "Map" && response_content{"error_str"}) => response_content{"error_str"} | 0;
			error = error_info.put({"skyCloudError": response_error, "skyCloudErrorMsg": response_error_str, "skyCloudReturnValue": response_content});
			is_bad_response = (response_content.isnull() || response_content == "null" || response_error || response_error_str);
			response_content;
		}
		latest_trips = function() {
			trips = ent:trips
                                .map(function(v, k) {
                                        v.values();
                                }).klog("Map: ")
				.values().klog("Values: ")
				.head().klog("Head: ");
			length = trips.length();
			(length > 5) => trips.slice(length - 5, length - 1) | trips;
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

		if not exists then
			noop()

		fired {
			raise pico event "new_child_request"
				attributes {
					"dname": nameFromId(vehicle_id),
					"color": "#FF69B4",
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
			send_directive("vehicle_ready", {
				"vehicle_id": vehicle_id
			})		
	}

	rule pico_child_initialized {
		select when wrangler child_initialized
		pre {
			the_vehicle_eci = event:attr("eci");
			the_vehicle_id = event:attr("id");
			vehicle_id = event:attr("rs_attrs") {"vehicle_id"};
		}
		if vehicle_id.klog("found vehicle_id: ") then every {
			event:send({ 
				"eci": the_vehicle_eci,
				"eid": "install-ruleset",
				"domain": "pico",
				"type": "new_ruleset",
				"attrs": {
					"rids": "track_trips;io.picolabs.subscription",
					"url": "https://raw.githubusercontent.com/andyyatteau/cs-462-lab7/master/test2.krl",
					"vehicle_id": vehicle_id
				}
			});
		}
		fired {
			ent:vehicles := ent:vehicles.defaultsTo({});
			ent:vehicles{[vehicle_id]} := {
				"eci":the_vehicle_eci, 
				"id": the_vehicle_id
			};
			raise wrangler event "subscription" 
				attributes {
                                        "name": vehicle_id,
                                        "name_space": "vehicle",
                                        "my_role": "controller",
                                        "subscriber_role": "vehicle",
                                        "channel_type": "subscription",
                                        "subscriber_eci": the_vehicle_eci
                                }; 
		}
	}

	rule delete_vehicle {
		select when car unneeded_vehicle
		pre {
			vehicle_id = event:attr("vehicle_id").klog("Vehicle Id: ");
			exists = ent:vehicles >< vehicle_id.klog("Exists: ");
			eci = meta:eci.klog("Eci: ");
			child_to_delete = childFromId(vehicle_id).klog("Vehicle to Delete: ");
			subscription_name = "vehicle:" + vehicle_id;
		}
		if exists then
			send_directive("vehicle_deleted", {
				"vehicle_id": vehicle_id
			});
		fired {
			raise wrangler event "subscription_cancellation"
                                attributes {
                                        "subscription_name": subscription_name
                                };
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

	rule request_fleet_report {
		select when fleet report_requested
		foreach vehicles() setting(subscription)
			pre {
				subs_attrs = subscription{"attributes"}.klog("Subscription attributes ");
			}
			if subs_attrs{"subscriber_role"} == "vehicle" then
				event:send({
					"eci": subs_attrs{"outbound_eci"},
					"eid": "report-requested",
					"domain": "fleet",
					"type": "report_needed"
				});
	}

	rule fleet_report_recieved {
		select when fleet report_ready
		pre {
			vehicle_id = event:attr("vehicle_id").klog("Report Vehicle Id: ");
			trips = event:attr("trips").klog("Report trips: ");
		}
		always {
			ent:trips := ent:trips.defaultsTo({});
			ent:trips{[vehicle_id]} := trips;
		}
	}	
}

