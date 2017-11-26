ruleset track_trips {
  meta {
    name "Track Trips"
    description <<
Lab 7
>>
    author "Andy Yatteau"
    logging on
    shares __testing
  }
  global {
    long_trip = "100"

    __testing = { "queries": [ { "name": "__testing" } ],
              "events": [ { "domain": "car", "type": "new_trip", "attrs": ["mileage"] } ]
    }
  }
  rule process_trip {
    select when car new_trip
    pre { mileage = event:attr("mileage") }
    send_directive("trip", {"length":mileage})
    always {
      raise explicit event "trip_processed"
        attributes event:attrs()
    }
  }

  rule find_long_trips {
    select when explicit trip_processed
    pre { mileage = event:attr("mileage") }
    always {
      raise explicit event "found_long_trip" attributes {
        "mileage": mileage
      } if (mileage > long_trip);
    }
  }
 
}
