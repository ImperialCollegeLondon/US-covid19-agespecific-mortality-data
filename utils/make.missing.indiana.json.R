library(data.table)
library(readxl)
library(rjson)

setwd("~/git/US-covid19-data-scraping")
path_to_data = 'data/'

#
# Process data up until yesterday
last.day = Sys.Date() - 1 # yesterday 


#
# Find date of json file
dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")

#
# Find date of json file
data_files = list.files(file.path(path_to_data, dates), full.names = T)
data_files_state = data_files[grepl(paste0('indiana', ".json"), data_files)]
dates_json = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))

#
# Find date of xlsx file
data_files = list.files(file.path(path_to_data, dates), full.names = T)
data_files_state = data_files[grepl(paste0('indiana', ".xlsx"), data_files)]
dates_xlsx = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))

dates = dates_xlsx[!dates_xlsx %in% dates_json]

#
# Create missing json
for(t in 1:length(dates)){
  #t = 1
  
  Date= dates[t]
  file = read_excel(file.path(path_to_data, Date, 'indiana.xlsx'))
  age_var_name = ifelse('m1d_agegrp' %in% names(file), 'm1d_agegrp', 'AGEGRP')
  death_var_name = ifelse('m1d_covid_deaths' %in% names(file), 'm1d_covid_deaths', 'COVID_DEATHS')
  
  file = subset(file, !get(age_var_name) %in% c('unknown', 'Unknown'))
  
  deaths = as.list(as.vector(unlist(file[,death_var_name])))
  names(deaths) = as.vector(unlist(file[,age_var_name]))
  
  json_df <- rjson::toJSON(deaths)
  outfile <- file.path(path_to_data, Date, 'indiana.json')
  write(json_df, file=outfile)
}


