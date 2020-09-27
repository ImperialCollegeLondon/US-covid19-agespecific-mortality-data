library(RCurl)

#setwd("~/git/US-covid19-data-scraping")

last.updated = "200926"

download.file("https://raw.githubusercontent.com/nychealth/coronavirus-data/master/case-hosp-death.csv", 
                     destfile = file.path("data/official", paste0("NYC_deaths_", last.updated, ".csv")) ,method = "curl")
