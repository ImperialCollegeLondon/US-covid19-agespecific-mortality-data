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


#
# process every state 
data.overall <- vector('list',nrow(states))
for(i in 1:nrow(states)){
  
  data = obtain.data(last.day, states$name[i], states$code[i], states$json[i])
  write.csv(data, file = file.path("data", "processed", last.day, paste0("DeathsByAge_",states$code[i],".csv")), row.names=FALSE)
  
  data.overall[[i]] = data
}
data.overall = do.call('rbind',data.overall)

#
# include Texas from 27/07 (day where the data start matching with JHU)
data.overall_woTX = subset(data.overall, code != "TX") 
data.overall_TX = subset(data.overall, code == "TX" & date > as.Date("2020-07-27")) 
data.overall = dplyr::bind_rows(data.overall_woTX, data.overall_TX)

#
# include NYC from 30/06 (day where the data start matching with NYC overall)
data.overall_woNYC = subset(data.overall, code != "NYC") 
data.overall_NYC = subset(data.overall, code == "NYC" & date > as.Date("2020-06-30")) 
data.overall = dplyr::bind_rows(data.overall_woNYC, data.overall_NYC)

#
# include Vermont from 15/06 (day where the data start matching with JHU)
data.overall_woVT = subset(data.overall, code != "VT") 
data.overall_VT = subset(data.overall, code == "VT" & date > as.Date("2020-06-15")) 
data.overall = dplyr::bind_rows(data.overall_woVT, data.overall_VT)


#
# save aggregated outputs in a single file
write.csv(data.overall, file = file.path("data", "processed", last.day, "DeathsByAge_US.csv"), row.names=FALSE)


#
# maintain a copy of the latest date in a consistent location
latest_folder = file.path("data", "processed", "latest")
latest_files = list.files(file.path("data", "processed", last.day), full.names=TRUE)
dir.create(latest_folder, showWarnings=FALSE)
file.copy(latest_files, latest_folder, recursive=TRUE, overwrite=TRUE)


cat("\n End Processing \n")
cat("\n Processed data are in data/", as.character(last.day), "/processed \n")
