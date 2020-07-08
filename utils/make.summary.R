# make table with first day and last day of recording

library(data.table)

<<<<<<< HEAD
=======

dates = seq.Date(as.Date("2020-03-22"), last.day, by = "day")

>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
json.states = data.table(code = c(     "AZ",
                                       "CA",
                                       "DE",
                                       "IN",
                                       "KS",
                                       "KY",
                                       "LA",
                                       "IA",
                                       "IL",
                                       "MO",
                                       "NC",
                                       "SC",
                                       "ND",
                                       "OK",
                                       "VT", 
                                       "MD",
                                       "MS", 
                                       "MA",
                                       "NYC",
<<<<<<< HEAD
                                       "NJ"),
=======
                                       "NJ",
                                       "FL",
                                       "MI",
                                       "NV",
                                       "NH",
                                       "OR",
                                       "PA",
                                       "VA",
                                       "WI",
                                       "WA",
                                       "AL"),
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
                         
                         name = c("arizona",
                                  "california",
                                  "delaware",
                                  "indiana",
                                  "kansas",
                                  "kentucky",
                                  "louisiana",
                                  "iowa",
                                  "illinois",
                                  "missouri",
                                  "NorthCarolina",
                                  "SouthCarolina",
                                  "NorthDakota",
                                  "oklahoma",
                                  "vermont",
                                  "maryland",
                                  "mississippi",
                                  "ma",
                                  "nyc",
<<<<<<< HEAD
                                  "new_jersey"
=======
                                  "new_jersey",
                                  "florida",
                                  "michigan",
                                  "nevada",
                                  "new_hampshire",
                                  "oregon",
                                  "pennsylvania",
                                  "virginia",
                                  "wisconsin",
                                  "washington",
                                  "alabama"
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
                                  
                         ),
                         state_name = c("Arizona",
                                  "California",
                                  "Delaware",
                                  "Indiana",
                                  "Kansas",
                                  "Kentucky",
                                  "Louisiana",
                                  "Iowa",
                                  "Illinois",
                                  "Missouri",
                                  "North Carolina",
                                  "South Carolina",
                                  "North Dakota",
                                  "Oklahoma",
                                  "Vermont",
                                  "Maryland",
                                  "Mississippi",
                                  "Massachusetts",
<<<<<<< HEAD
                                  "New York",
                                  "New Jersey"
                                  
                         ),
                        
                         first.day = as.Date(c(
                           "2020-05-13",
                           "2020-05-13",
                           "2020-05-12",
                           "2020-05-13",
                           "2020-05-13",
                           "2020-05-13",
                           "2020-05-12",
                           "2020-05-13",
                           "2020-05-14",
                           "2020-05-13",
                           "2020-05-13",
                           "2020-05-14",
                           "2020-05-14",
                           "2020-05-13",
                           "2020-05-13",
                           "2020-05-14",
                           "2020-05-12",
                           "2020-04-20",
                           "2020-04-14",
                           "2020-05-06")),
                         last.day = c(last.day,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day-1,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day-6,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day,
                                      last.day-3
                                      
                         ),
=======
                                  "New York City",
                                  "New Jersey",
                                  "Florida",
                                  "Michigan",
                                  "Nevada",
                                  "New Hampshire",
                                  "Oregon",
                                  "Pennsylvania",
                                  "Virginia",
                                  "Wisconsin",
                                  "Washington",
                                  "Alabama"
                                  
                         ),
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
                         json = 1)

other.states = data.table(code = c("GA", 
                               #    "NY", 
                                   "TX", 
<<<<<<< HEAD
                                   "FL", 
=======
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
                                   "CDC",
                                   "ID",
                                   "CT",
                                   "CO",
<<<<<<< HEAD
                               "WA"),
                              name = c("georgia",
                            #           "New York",
                                       "texas",
                                       "florida",
=======
                               #"WA",
                               "AK",
                               "RI",
                               "TN",
                               "ME"),
                               name = c("georgia",
                            #           "New York",
                                       "texas",
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
                                       "cdc",
                                       "idaho",
                                       "connecticut",
                                       "colorado",
<<<<<<< HEAD
                            "washington"),
                          state_name = c("Georgia",
                                         #           "New York",
                                         "Texas",
                                         "Florida",
=======
                            #"washington",
                            "alaska",
                            "rhode_island",
                            "tennessee",
                            "maine"),
                          state_name = c("Georgia",
                                         #           "New York",
                                         "Texas",
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
                                         "CDC",
                                         "Idaho",
                                         "Connecticut",
                                         "Colorado",
<<<<<<< HEAD
                                         "Washington"),
                          
                              first.day = as.Date(c("2020-05-07", 
                                #                    "2020-05-07", 
                                                    "2020-05-06", 
                                                    "2020-03-27", 
                                                    "2020-05-06",
                                                    "2020-05-13",
                                                    "2020-05-11",
                                                    "2020-05-12",
                                                     "2020-05-04")), 
                          last.day = c(last.day,
                                 #      last.day,
                                       as.Date("2020-05-15"),
                                       last.day,
                                       last.wednesday,
                                       last.day - 2,
                                       last.day,
                                       last.day,
                                 last.monday
                                       
                          ),
                              json=0)

table.states = rbind(json.states, other.states)
=======
                                        # "Washington",
                                         "Alaska",
                                         "Rhode Island",
                                         "Tennessee",
                                        "Maine"),
                              json=0)

table.states = rbind(json.states, other.states) 


>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
