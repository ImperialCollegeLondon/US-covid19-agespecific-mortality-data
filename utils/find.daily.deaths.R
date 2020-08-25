
find_daily_deaths = function(dates, h_data = NULL, state_code, state_name = NULL, daily.data.csv_and_xlsx = 0, json = 0, historic.data = 0)
{
  
  first.day = min(dates)
  
  data = NULL
  
  for(t in 1:length(dates)){
    
    Date = dates[t]
    print(Date)
    
    # read daily daily update if csv or xlsx
    if(daily.data.csv_and_xlsx){
      file_format = ".csv"
      if(state_code %in% c("TX")) file_format = ".xlsx"
      file = file.path(path_to_data, Date, paste0(state_name, file_format))
      tmp = do.call(paste0("read.", state_code, ".file"), list(file, Date))
    }
    
    # read daily daily update if json
    if(json)
    {
      res = read_json(Date, state_name, state_code, data)
      json_data = res[[1]]; tmp = res[[2]]
    }
    
    # select Date in historical data 
    if(historic.data)
    {
      tmp = subset(h_data, date == Date)
    }
    
    for(age_group in tmp$age){

      if(json){
        tmp = check_format_json(tmp, json_data, state_name, age_group, Date)
      }
      
      
      if(Date > first.day){
        # compute daily death
        cum.death.t_1 = tmp[which(tmp$age == age_group & tmp$date == Date),]$cum.deaths
        cum.death.t_0 =  data[which(data$age == age_group & data$date == (Date-1)),]$cum.deaths
        daily.deaths = cum.death.t_1 - cum.death.t_0 
        
        # if there is missing data at t-1
        if((Date - 1) %notin% dates){
          n.lost.days = as.numeric(Date - dates[which(dates == Date)-1] -1)
          lost.days = Date - c(n.lost.days:1)
          cum.death.t_lag = tmp[which(tmp$age == age_group & tmp$date == Date),]$cum.deaths
          cum.death.t_0 =  data[which(data$age == age_group & data$date == (Date-n.lost.days-1)),]$cum.deaths
          
          # incremental deaths is distributed equally among the missing days
          daily.deaths = round((cum.death.t_lag - cum.death.t_0 )/(n.lost.days+1))
          
          # if the cumulative death at t0 is greater than the one at tlag
          if( daily.deaths < 0 ) { 
            # decrease the daily death at t0 by the difference, or set it to 0 if the difference is negative
            data[which(data$date == (Date-n.lost.days-1) & data$age == age_group),]$daily.deaths = 
              max(0, data[which(data$date == (Date-n.lost.days-1)& data$age == age_group),]$daily.deaths + daily.deaths)
            # set daily death at t to 0
            daily.deaths = 0
          }
          
          data = rbind(data, data.table(age = age_group, 
                                        date = lost.days, 
                                        cum.deaths = round(cum.death.t_0 + daily.deaths*c(1:n.lost.days)), 
                                        daily.deaths = rep(daily.deaths, n.lost.days), 
                                        code = state_code))
        }
        
        stopifnot(is.numeric(daily.deaths) & !is.null(daily.deaths))
        
        # if the cumulative death at t-1 is greater than the one at t
        if(daily.deaths<0){
          # decrease the daily death at t-1 by the difference, or set it to 0 if the difference is negative 
          data[which(data$age == age_group & data$date == (Date-1)),]$daily.deaths = max(data[which(data$age == age_group & data$date == (Date-1)),]$daily.deaths + daily.deaths,0)
          # set daily death at t to 0
          daily.deaths = 0
        }
        tmp[which(tmp$age == age_group & tmp$date == Date),]$daily.deaths = daily.deaths
      }
      
    }
    data = rbind(data, tmp)
  }
  
  # overwrite cumulative deaths
  data = data %>%
    group_by(age) %>%
    mutate(cum.deaths.first.day  = cum.deaths[which.min(cum.deaths)], 
           cum.deaths = cumsum(replace_na(daily.deaths, 0)) + cum.deaths.first.day) %>%
    select(-c(cum.deaths.first.day))
  
  # Reorder data
  data <- with(data, data[order(date, age, cum.deaths, daily.deaths, code), ])
  data <- data[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
  return(data)
}

  
