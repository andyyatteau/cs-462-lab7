ruleset trip_store_multiple {
    meta {
        name "Trip Store for Multiple Picos"
        description <<
Lab 7
>>
    author "Andy Yatteau"
    logging on
        shares __testing, trips, long_trips, short_trips
        provides trips, long_trips, short_trips
  }

  global {
            __testing = { "queries": [ { "name": "__testing" }, { "name": "trips" }, { "name": "long_trips" }, { "name": "short_trips" } ],
              "events": [ { "domain": "explicit", "type": "trip_processed", "attrs": ["mileage"] },  
              { "domain": "explicit", "type": "found_long_trip", "attrs": ["mileage"] },
              { "domain": "car", "type": "trip_reset" } ]
            }

    trips = function() {
            ent:trips
        }
        long_trips = function() {
            ent:long_trips
        }
    short_trips = function() {
      trips = ent:trips.map(function(x) {
        x{"mileage"}
      });
      long_trips = ent:long_trips.map(function(x) {
        x{"mileage"}
      });
      trips.difference(long_trips);
    }
  }

  rule collect_trips {
    select when explicit trip_processed
    pre {
      mileage = event:attr("mileage");
      trips = ent:trips || [];
      the_trip = {"mileage":mileage, "timestamp":time:now()};
      trips = trips.append(the_trip);
    }
    always {
      ent:trips := trips;
    }
  }

  rule collect_long_trips {
    select when explicit found_long_trip
    pre {
      mileage = event:attr("mileage");
      long_trips = ent:long_trips || [];
      the_trip = {"mileage":mileage, "timestamp":time:now()};
      long_trips = long_trips.append(the_trip);
    }
        always {
            ent:long_trips := long_trips;
        }
  }

  rule clear_trips {
    select when car trip_reset
    always {
      ent:trips := [];
      ent:long_trips := [];
    }
  }

  rule generate_report {
    select when car generate_report
    pre {
      rcn = event:attr("rcn")
      eci = event:attr("sender_eci")
      vehicle_id = event:attr("vehicle_id")
      attributes = {"rcn": rcn,
        "vehicle_id": vehicle_id,
        "trips": ent:trips
      }
    }
    event:send({ "eci": eci, "eid": "send_report", "domain": "car", "type": "send_report", "attrs": attributes})
  }
}
