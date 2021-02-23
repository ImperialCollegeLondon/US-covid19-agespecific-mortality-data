library("rjson")
library(readxl)
library(tidyverse)

path_to_data = "data"
path_to_JHU_data = "data/official/jhu_death_data_padded_210222.rds"
path_to_NYC_data = "data/official/NYC_deaths_210222.csv"
states_w_one_day_delay = c("CT", "DC","FL","MO","MS","SC",  'HI')

`%notin%` = Negate(`%in%`)

source("utils/summary.functions.R")
source("utils/adjust.functions.R")
source("utils/read.json.data.functions.R")
source("utils/read.daily-historical.data.functions.R")
source("utils/sanity.check.function.R")

obtain.data = function(last.day, state_name, state_code, json){
  
  ## 1. STATES WITH RULE BASED FUNCTION
  states.historical.data = c("CT", "TN", "ME", "WI", "VA","TX")
  states.daily.data = c("GA", "ID", "AK", "RI", "CDC")
  
  # file with entire time series
  if(state_code %in% states.historical.data) data = obtain.historic.data.csv_and_xlsx(last.day, state_name, state_code)
  
  # file with entire time series and daily deaths (rather than cumulative deaths)
  if(state_code %in% "NM")  data = do.call(paste0("read.", state_code, ".file"), list(last.day))
  
  # daily file
  if(state_code %in% states.daily.data) data = obtain.daily.data.csv_and_xlsx(last.day, state_name, state_code)
  
  
  ##  2, STATES WITH .JSON file
  if(json == 1) data = obtain.json.data(last.day, state_name, state_code)

  return(data)
  
}

obtain.daily.data.csv_and_xlsx = function(last.day, state_name, state_code){
  
  cat("\n Processing", state_name,  "\n")
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  file_format = ".csv"
  if(state_code %in% c("TX")) file_format = ".xlsx"
  
  # find dates with data
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0(state_name, file_format), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  
  # create time series
  data = create_time_series(dates = dates, state_name = state_name, state_code = state_code, daily.data.csv_and_xlsx = TRUE)
  
  # ensure that cumulative death is increasing in the data
  data = ensure_increasing_cumulative_deaths(dates = dates, h_data = data)
  
  # find daily deaths
  data.list = vector(mode = "list", length = length(unique(data$code)))
  for(i in 1:length(unique(data$code))){
    data.list[[i]] = find_daily_deaths(dates = dates, h_data = subset(data, code == unique(data$code)[i]), state_code = unique(data$code)[i])
  }
  data = do.call("rbind", data.list)

  
  return(data.table(data))
}

obtain.historic.data.csv_and_xlsx = function(last.day, state_name, state_code){
  
  cat("\n Processing ", state_name, " \n")
  
  # read the file 
  if(state_code != 'TX'){
    tmp = do.call(paste0("read.", state_code, ".file"), list(last.day))
  } else{
    tmp = do.call(paste0("read.", state_code, ".file.time.series"), list(last.day))
  }
  
  # find dates with data
  dates = unique(sort(tmp$date))
  
  # create time series
  data = create_time_series(dates = dates, h_data = tmp, state_code = state_code, historic.data = TRUE)
  
  # ensure that cumulative death is increasing in the data
  data = ensure_increasing_cumulative_deaths(dates = dates, h_data = data)
  
  # find daily deaths
  data = find_daily_deaths(dates = dates, h_data = data, state_code = state_code)
  
  return(data.table(data))
}

obtain.json.data = function(last.day, state_name, state_code){
  
  cat(paste0("\n Processing ", state_name,"\n"))
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  # find date with data
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0(state_name, ".json"), data_files)]
  if(state_name == "ma")  data_files_state = data_files_state[!grepl("oklahoma.json|alabama.json", data_files_state)] # we named massasschussets "ma" ...
  if(state_name == "kansas")  data_files_state = data_files_state[!grepl("arkansas.json", data_files_state)] 
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  
  if(state_name == "alabama") dates = dates[which(dates >= as.Date("2020-05-03"))] # they changed age groups at this date
  if(state_name == "minnesota") dates = dates[which(dates >= as.Date("2020-05-21"))] # they changed age groups at this date
  if(state_name == "mississippi") dates = dates[which(dates >= as.Date("2020-09-30"))] # they changed age groups at this date
  if(state_name == "wyoming") dates = dates[which(dates >= as.Date("2020-10-29"))] # they changed age groups at this date
  if(state_name == "NorthCarolina") dates = dates[which(dates %notin% seq.Date(as.Date("2020-05-13"), as.Date("2020-05-19"), by = "day"))] # incorrect age groups
  
  # create time series
  data = create_time_series(dates = dates, state_name = state_name, state_code = state_code, json = TRUE)
  
  # ensure that cumulative death is increasing in the data
  data = ensure_increasing_cumulative_deaths(dates = dates, h_data = data)
  
  # find daily deaths
  data = find_daily_deaths(dates = dates, h_data = data, state_code = state_code)
  
  # make human readable age band
  data = fix_age_json(data, state_code)
    
  return(data)
} 


