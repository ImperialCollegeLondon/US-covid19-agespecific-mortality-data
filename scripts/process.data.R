library(data.table)

#path_to_data = "data"

source("utils/process.data.by.state.R")

dir.create(file.path("data", "processed"), showWarnings = FALSE)

cat("\n Begin Processing \n")

last.day = as.Date("2020-05-09") # default to last make files
#last.day = Sys.Date() # TO DO: default to today
days_week = last.day - 0:6
last.monday = days_week[which(weekdays(days_week) == "Monday")]
last.wednesday = days_week[which(weekdays(days_week) == "Wednesday")]
first.day.states = data.table(code = c("GA", "NY", "NYC", "TX", "NJ", "FL", "CDC"),
                              first.day = as.Date(c("2020-05-07", "2020-05-07", "2020-04-14", "2020-05-06", "2020-05-06",  "2020-03-27", "2020-05-06")))

data.nyc = obtain.nyc.data(first.day.states[which(first.day.states$code == "NYC"),]$first.day, last.day-1)
write.csv(data.nyc, file = file.path("data", "processed", "DeathsByAge_NYC.csv"))

data.fl = obtain.fl.data(first.day.states[which(first.day.states$code == "FL"),]$first.day, last.day-1)
write.csv(data.fl, file = file.path("data", "processed", "DeathsByAge_FL.csv"))

data.wa = obtain.wa.data(last.monday)
write.csv(data.wa, file = file.path("data", "processed", "DeathsByAge_WA.csv"))

data.tx = obtain.tx.data(first.day.states[which(first.day.states$code == "TX"),]$first.day, last.day-1)
write.csv(data.tx, file = file.path("data", "processed", "DeathsByAge_TX.csv"))

data.ga = obtain.ga.data(first.day.states[which(first.day.states$code == "GA"),]$first.day, last.day)
write.csv(data.ga, file = file.path("data", "processed", "DeathsByAge_GA.csv"))

data.cdc = obtain.cdc.data(first.day.states[which(first.day.states$code == "CDC"),]$first.day, last.wednesday)
write.csv(data.cdc, file = file.path("data", "processed", "DeathsByAge_CDC.csv"))

cat("\n End Processing \n")
cat("\n Processed data are in data/processed \n")
