library(RCurl)

#setwd("~/git/US-covid19-data-scraping")

last.updated = "210114"

download.file("https://raw.githubusercontent.com/nychealth/coronavirus-data/master/trends/data-by-day.csv", 
                     destfile = file.path("data/official", paste0("NYC_deaths_", last.updated, ".csv")) ,method = "curl")
