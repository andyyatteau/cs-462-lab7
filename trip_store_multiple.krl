ruleset trip_store_multiple {
    meta {
        name "Trip Store for Multiple Picos"
        description <<
Lab 6
>>
    author "Andy Yatteau"
    logging on
        shares __testing, trips, long_trips, short_trips
        provides trips, long_trips, short_trips
  }

  global {
            __testing = { "queries": [ { "name": "__testing" }, { "name": "trips" }, { "name": "long_trips" }, { "name": "short_trips" } ],
              "events": [ { "domain": "explicit", "type": "processed_trip", "attrs": ["mileage"] },  
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
      ent:trips.difference(ent:long_trips);
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
}
