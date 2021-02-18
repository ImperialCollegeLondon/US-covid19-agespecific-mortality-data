library(data.table)
library(rjson)
library(dplyr)

setwd("~/git/US-covid19-data-scraping")
path_to_data = 'data'

make_doc_json()

make_doc_json = function(){
  #
  # Process data up until yesterday
  last.day = Sys.Date() - 1 # yesterday 
  
  
  #
  # Find date of json file
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  #
  # Find date of json file
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0('doc', ".json"), data_files)]
  dates_json = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  
  #
  # Find date of xlsx file
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0('doc', ".csv"), data_files)]
  dates_csv = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  
  dates = seq.Date(max(dates_json) + 1, max(dates_csv), by = 'day') 
  
  file = as.data.table( reshape2::melt(read.csv(file.path(path_to_data, max(dates_csv), 'doc.csv'))), id.vars = 'X')
  file = file[-c(1:2621),] # keep only 2021
  file[, date := as.Date(paste0(variable, '.2021'), format('X%d.%b.%Y'))]
  setnames(file, 'X', 'age')
  file = subset(file, !age %in% c('Age', "All"))
  file = select(file, date, age, value)
  
  #
  # Create missing json
  for(t in 1:length(dates)){
    #t = 1
    
    Date= dates[t]
    
    file_t = subset(file, date == Date)
    
    deaths = as.list(as.vector(unlist(file_t[,'value'])))
    names(deaths) = as.vector(unlist(file_t[,'age']))
    
    json_df <- rjson::toJSON(deaths)
    outfile <- file.path(path_to_data, Date, 'doc.json')
    write(json_df, file=outfile)
  }
  
}

