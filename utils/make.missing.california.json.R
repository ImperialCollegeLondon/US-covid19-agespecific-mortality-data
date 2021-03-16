library(data.table)
library(rjson)
library(dplyr)

setwd("~/git/US-covid19-data-scraping")
path_to_data = 'data'

make_california_json()

make_california_json = function(){
  #
  # Process data up until yesterday
  last.day = Sys.Date() - 1 # yesterday 
  
  
  #
  # Find date of json file
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  #
  # Find date of json file
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0('california', ".json"), data_files)]
  dates_json = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  
  #
  # Find date of xlsx file
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0('california', ".csv"), data_files)]
  dates_csv = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  
  dates = seq.Date(max(dates_json) + 1, max(dates_csv), by = 'day') 
  
  file = as.data.table( read.csv(file.path(path_to_data, max(dates_csv), 'california.csv')) )
  file[, date := as.Date(report_date)]
  file[demographic_value == '65', demographic_value := '65+']
  file = subset(file, demographic_category == 'Age Group' & date %in% dates & !demographic_value %in% c('missing', 'Total'))
  file = select(file, date, demographic_value, deaths)
  
  dates = unique(file$date)
  if(length(dates) < 1) stop()
  
  #
  # Create missing json
  for(t in 1:length(dates)){
    #t = 1
    
    Date= dates[t]
    
    file_t = subset(file, date == Date)
    
    deaths = as.list(as.vector(unlist(file_t[,'deaths'])))
    names(deaths) = as.vector(unlist(file_t[,'demographic_value']))
    
    json_df <- rjson::toJSON(deaths)
    outfile <- file.path(path_to_data, Date, 'california.json')
    write(json_df, file=outfile)
  }
  
}
