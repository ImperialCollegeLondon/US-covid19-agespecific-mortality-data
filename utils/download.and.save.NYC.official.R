library(RCurl)

#setwd("~/git/US-covid19-data-scraping")

<<<<<<< HEAD
last.updated = "200528"
=======
last.updated = "200707"
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd

download.file("https://raw.githubusercontent.com/nychealth/coronavirus-data/master/case-hosp-death.csv", 
                     destfile = file.path("data/official", paste0("NYC_deaths_", last.updated, ".csv")) ,method = "curl")
