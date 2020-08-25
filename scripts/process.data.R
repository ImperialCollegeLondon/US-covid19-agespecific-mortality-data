library(data.table)

#setwd("~/git/US-covid19-data-scraping")

time.daily.update = strptime("22:00:00", "%H:%M:%S")

if(Sys.time() > time.daily.update) last.day = Sys.Date()  # today
if(Sys.time() < time.daily.update) last.day = Sys.Date() - 1 # yesterday 
 
source("utils/obtain.data.R")
source("utils/make.summary.R") # table.states is a summary of all states extracted

cat("\n Begin Processing \n")

dir.create(file.path("data", "processed", last.day), showWarnings = FALSE)

states = subset(table.states, code != "CDC")

data.overall = NULL
for(i in 1:nrow(states)){
  data = obtain.data(last.day, states$name[i], states$code[i], states$json[i])
  write.csv(data, file = file.path("data", "processed", last.day, paste0("DeathsByAge_",states$code[i],".csv")), row.names=FALSE)
  data.overall = dplyr::bind_rows(data, data.overall)
}

# include texas from 27/07
data.overall_woTX = subset(data.overall, code != "TX") 
data.overall_TX = subset(data.overall, code == "TX" & date > as.Date("2020-07-27")) 
data.overall = dplyr::bind_rows(data.overall_woTX, data.overall_TX)
write.csv(data.overall, file = file.path("data", "processed", last.day, "DeathsByAge_US.csv"), row.names=FALSE)

cat("\n End Processing \n")
cat("\n Processed data are in data/", as.character(last.day), "/processed \n")
