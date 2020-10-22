library(data.table)

#setwd("~/git/US-covid19-data-scraping")

#
# Process data up until yesterday
last.day = Sys.Date() - 1 # yesterday 

#
# Load code
source("utils/obtain.data.R")
source("utils/make.summary.R") # table.states is a summary of all states extracted

#
# Housekeeping
dir.create(file.path("data", "processed", last.day), showWarnings = FALSE)

#
# process every state 
cat("\n Begin Processing \n")

data.overall <- vector('list',nrow(table.states))
for(i in 1:nrow(table.states)){
  
  data = obtain.data(last.day, table.states$name[i], table.states$code[i], table.states$json[i])
  write.csv(data, file = file.path("data", "processed", last.day, paste0("DeathsByAge_",table.states$code[i],".csv")), row.names=FALSE)
  
  if(table.states$code[i] == "CDC") next
  
  data.overall[[i]] = copy(data)
  
}
data.overall = do.call('rbind',data.overall)

#
# Adjust age group (to match 5 y age band) 
data.overall_adj = adjust_to_5y_age_band(data.overall)

#
# Remove days that disagree with JHU
data.overall_adj = keep_days_match_JHU(data.overall_adj)

#
# save aggregated outputs in a single file
write.csv(data.overall, file = file.path("data", "processed", last.day, "DeathsByAge_US.csv"), row.names=FALSE)
write.csv(data.overall_adj, file = file.path("data", "processed", last.day, "DeathsByAge_US_adj.csv"), row.names=FALSE)

#
# maintain a copy of the latest date in a consistent location
latest_folder = file.path("data", "processed", "latest")
latest_files = list.files(file.path("data", "processed", last.day), full.names=TRUE)
dir.create(latest_folder, showWarnings=FALSE)
invisible(file.copy(latest_files, latest_folder, recursive=TRUE, overwrite=TRUE))

cat("\n End Processing \n")
cat("\n Processed data are in data/", as.character(last.day), "/processed \n")
