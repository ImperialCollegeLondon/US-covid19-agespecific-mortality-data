library(data.table)

#path_to_data = "data"
#setwd("~/git/US-covid19-data-scraping")

time.daily.update = strptime("22:00:00", "%H:%M:%S")

if(Sys.time() > time.daily.update) last.day = Sys.Date() - 1 # yesterday
if(Sys.time() < time.daily.update) last.day = Sys.Date() - 2 # two days ago 

days_week = last.day - 0:6
last.monday = days_week[which(weekdays(days_week) == "Monday")]
last.wednesday = days_week[which(weekdays(days_week) == "Wednesday")]

source("utils/process.data.by.state.R")
source("utils/make.summary.R") # table.states is a summary of all states extracted

cat("\n Begin Processing \n")

dir.create(file.path("data", last.day, "processed"), showWarnings = FALSE)

## STATES WITH RULE BASED FUNCTION
rulebased.states = subset(table.states, json == 0 & code != "CDC" & code != "ID")
data.overall = NULL
# remove Idaho because there is missing days and we are not sure about the update frequency

for(i in 1:nrow(rulebased.states)){
  data = obtain.rulebased.data(rulebased.states$first.day[i], rulebased.states$last.day[i],  rulebased.states$code[i])
  write.csv(data, file = file.path("data", last.day, "processed", paste0("DeathsByAge_",rulebased.states$code[i],".csv")), row.names=FALSE)
  data.overall = dplyr::bind_rows(data, data.overall)
}


## STATES WITH .JSON file
json.states = subset(table.states, json == 1 & name != "kansas" & name != "iowa" & name != "SouthCarolina")
# remove kansas because not sure about the update days and iowa because change of age cat

for(i in 1:nrow(json.states)){
  data = obtain.json.data(json.states$first.day[i], json.states$last.day[i], json.states$name[i], json.states$code[i])
  write.csv(data, file = file.path("data", last.day, "processed", paste0("DeathsByAge_",json.states$code[i],".csv")), row.names=FALSE)
  data.overall = dplyr::bind_rows(data, data.overall)
}

data.overall = subset(data.overall, code != "WA" & code != "TX" & code != "NJ")# data does not match with JHU or IHME.
write.csv(data.overall, file = file.path("data", last.day, "processed", "DeathsByAge_US.csv"), row.names=FALSE)

cat("\n End Processing \n")
cat("\n Processed data are in data/processed \n")
