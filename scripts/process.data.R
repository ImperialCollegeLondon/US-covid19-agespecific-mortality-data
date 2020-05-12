library(data.table)

#path_to_data = "data"
#setwd("~/git/US-covid19-data-scraping")

source("utils/process.data.by.state.R")

cat("\n Begin Processing \n")

time.daily.update = strptime("16:00:00", "%H:%M:%S")
  
if(Sys.time() > time.daily.update) last.day = Sys.Date() # today
if(Sys.time() < time.daily.update) last.day = Sys.Date() - 1 # yesterday 

dir.create(file.path("data", last.day, "processed"), showWarnings = FALSE)

days_week = last.day - 0:6
last.monday = days_week[which(weekdays(days_week) == "Monday")]
last.wednesday = days_week[which(weekdays(days_week) == "Wednesday")]
first.day.states = data.table(code = c("GA", "NY", "NYC", "TX", "NJ", "FL", "CDC"),
                              first.day = as.Date(c("2020-05-07", "2020-05-07", "2020-04-14", "2020-05-06", "2020-05-06",  "2020-03-27", "2020-05-06")))

data.nyc = obtain.nyc.data(first.day.states[which(first.day.states$code == "NYC"),]$first.day, last.day-4)
write.csv(data.nyc, file = file.path("data", last.day, "processed", "DeathsByAge_NYC.csv"), row.names=FALSE)

data.fl = obtain.fl.data(first.day.states[which(first.day.states$code == "FL"),]$first.day, last.day-4)
write.csv(data.fl, file = file.path("data", last.day, "processed", "DeathsByAge_FL.csv"), row.names=FALSE)

data.wa = obtain.wa.data(last.monday)
write.csv(data.wa, file = file.path("data", last.day, "processed", "DeathsByAge_WA.csv"), row.names=FALSE)

data.tx = obtain.tx.data(first.day.states[which(first.day.states$code == "TX"),]$first.day, last.day)
write.csv(data.tx, file = file.path("data", last.day, "processed", "DeathsByAge_TX.csv"), row.names=FALSE)

data.ga = obtain.ga.data(first.day.states[which(first.day.states$code == "GA"),]$first.day, last.day)
write.csv(data.ga, file = file.path("data", last.day, "processed", "DeathsByAge_GA.csv"), row.names=FALSE)

data.cdc = obtain.cdc.data(first.day.states[which(first.day.states$code == "CDC"),]$first.day, last.wednesday)
write.csv(data.cdc, file = file.path("data", last.day, "processed", "DeathsByAge_CDC.csv"), row.names=FALSE)

data.ct = obtain.ct.data(last.day-1)
write.csv(data.ct, file = file.path("data", last.day, "processed", "DeathsByAge_CT.csv"), row.names=FALSE)

data.co = obtain.co.data(last.day)
write.csv(data.co, file = file.path("data", last.day, "processed", "DeathsByAge_CO.csv"), row.names=FALSE)

data.overall = dplyr::bind_rows(data.fl, data.tx, data.ga, data.ct, data.co) # do not include WA because problematic delay nor NYC because not overall data yet
write.csv(data.overall, file = file.path("data", last.day, "processed", "DeathsByAge_US.csv"), row.names=FALSE)

cat("\n End Processing \n")
cat("\n Processed data are in data/processed \n")
