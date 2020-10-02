create_time_series = function(dates, h_data = NULL, state_code, state_name = NULL, daily.data.csv_and_xlsx = 0, json = 0, historic.data = 0)
{
  
  data = NULL
  
  for(t in 1:length(dates)){
    
    Date = dates[t]
    
    #
    # read daily update 
    
    #if csv or xlsx
    if(daily.data.csv_and_xlsx){
      file_format = ".csv"
      if(state_code %in% c("TX")) file_format = ".xlsx"
      file = file.path(path_to_data, Date, paste0(state_name, file_format))
      tmp = as.data.table( do.call(paste0("read.", state_code, ".file"), list(file, Date)) )
    }
    
    #if json
    if(json)
    {
      res = read_json(Date, state_name, state_code, data)
      json_data = res[[1]]; tmp = res[[2]]
      
      for(age_group in tmp$age){
        tmp = check_format_json(tmp, json_data, state_name, age_group, Date)
      }
      
    }
    
    # if select Date for historical data 
    if(historic.data)
    {
      tmp = as.data.table( subset(h_data, date == Date) )
    }
    
    data = rbind(data, tmp)
  }
  
  return(data)
}

ensure_increasing_cumulative_deaths = function(dates, h_data)
{
  
  for(t in 1:length(dates)){
    
    Date = rev(dates)[t]
    print(Date)
    #
    # check if cumulative death is strictly dicreasing from last date to first date
    
    for(age_group in unique(h_data$age)){
      
      
      if(Date < max(dates)){
        
        # if cumulative date at date t < date t - 1, fix cum deaths at date t - 1 to the one at date t.
        if(h_data[age == age_group & date == Date, cum.deaths] > h_data[age == age_group & date == rev(dates)[t-1], cum.deaths]){
          h_data[age == age_group & date == Date,]$cum.deaths = h_data[age == age_group & date == rev(dates)[t-1], cum.deaths]
        }
        
      }
    }
  }
  
  return(h_data)
}

find_daily_deaths = function(dates, h_data, state_code)
{
  
  first.day = min(dates)
  
  data = NULL
  
  for(t in 1:length(dates)){
    
    Date = dates[t]
    #print(Date)
    
    #
    # read daily daily update 
    tmp = as.data.table( subset(h_data, date == Date) )
    
    for(age_group in tmp$age){
      
      if(Date > first.day){
        # compute daily death
        cum.death.t_1 = tmp[age == age_group & date == Date,]$cum.deaths
        cum.death.t_0 =  data[age == age_group & date == (Date-1),]$cum.deaths
        daily.deaths = cum.death.t_1 - cum.death.t_0 
        
        # if there is missing data at t-1
        if((Date - 1) %notin% dates){
          n.lost.days = as.numeric(Date - dates[which(dates == Date)-1] -1)
          lost.days = Date - c(n.lost.days:1)
          cum.death.t_lag = tmp[age == age_group & date == Date,]$cum.deaths
          cum.death.t_0 =  data[age == age_group & date == (Date-n.lost.days-1),]$cum.deaths
          
          # incremental deaths is distributed equally among the missing days
          daily.deaths.lost.days = generate_dailydeaths(n.lost.days+1, cum.death.t_lag - cum.death.t_0)
          daily.deaths = daily.deaths.lost.days[1]
          
          data = rbind(data, data.table(age = age_group, 
                                        date = lost.days, 
                                        cum.deaths = round(cum.death.t_0 + daily.deaths*c(1:n.lost.days)), 
                                        daily.deaths = daily.deaths.lost.days[-1], 
                                        code = state_code))
          
        }
        
        stopifnot(daily.deaths >= 0)
        
        tmp[which(tmp$age == age_group & tmp$date == Date),]$daily.deaths = daily.deaths
      }
      
    }
    data = rbind(data, tmp)
  }
  
  # overwrite cumulative deaths
  data_processed = data %>%
    group_by(age) %>%
    mutate(cum.deaths.first.day  = cum.deaths[which.min(cum.deaths)], 
           cum.deaths = cumsum(replace_na(daily.deaths, 0)) + cum.deaths.first.day) %>%
    select(-c(cum.deaths.first.day))

  # sanity check: cumulative day on last day are equal to the one provided by the DoH
  sanity_check(data, data_processed, max(dates))
  
  # Reorder data
  data_processed <- with(data, data[order(data_processed, age, cum.deaths, daily.deaths, code), ])
  data_processed <- data_processed[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
  return(data)
}

generate_dailydeaths = function(n,s){
  num = floor(s/n)
  nums = rep(num, n)
  i = n
  while(sum(nums) != s){
    nums[i] = nums[i] + 1
    i = i - 1
  }

 stopifnot(sum(nums) == s)
  
  return(nums)
}

modify_ageband = function(data, state_name, state_code)
{
  
  data = as.data.table( data )
  data[, age := as.character(age)]
  
  #
  # modify age band
  data[, age := ifelse(age == "0-10", "0-9", age)]
  data[, age := ifelse(age == "0-17", "0-19", age)]
  data[, age := ifelse(age == "0-18", "0-19", age)]
  data[, age := ifelse(age == "5-17", "5-19", age)]
  data[, age := ifelse(age == "10-18", "10-19", age)]
  data[, age := ifelse(age == "11-20", "10-19", age)]
  data[, age := ifelse(age == "18-24", "20-24", age)]
  data[, age := ifelse(age == "18-29", "20-29", age)]
  data[, age := ifelse(age == "18-34", "20-34", age)]
  data[, age := ifelse(age == "18-35", "20-34", age)]
  data[, age := ifelse(age == "18-40", "20-39", age)]
  data[, age := ifelse(age == "18-44", "20-44", age)]
  data[, age := ifelse(age == "18-49", "20-49", age)]
  data[, age := ifelse(age == "19-29", "20-29", age)]
  data[, age := ifelse(age == "19-64", "20-64", age)]
  data[, age := ifelse(age == "21-30", "20-29", age)]
  data[, age := ifelse(age == "31-40", "30-39", age)]
  data[, age := ifelse(age == "36-49", "35-49", age)]
  data[, age := ifelse(age == "41-50", "40-49", age)]
  data[, age := ifelse(age == "41-60", "40-59", age)]
  data[, age := ifelse(age == "51-60", "50-59", age)]
  data[, age := ifelse(age == "61-70", "60-69", age)]
  data[, age := ifelse(age == "61-80", "60-79", age)]
  data[, age := ifelse(age == "65-76", "65-74", age)]
  data[, age := ifelse(age == "71-80", "70-79", age)]
  data[, age := ifelse(age == "81+", "80+", age)]
  
  
  #
  # Aggregate
  tmp = subset(data, age == "0-1") 
  for(loc in unique(tmp$code)){
    tmp1 = subset(data, code == loc)
    age_from1 = unique(tmp1$age)[which(grepl('1-',unique(tmp1$age)))]
    tmp1_agg = tmp1[age %in% c("0-1", age_from1), list(cum.deaths = sum(cum.deaths),
                                                       daily.deaths = sum(daily.deaths)),
                    by = c("date", "code")]
    tmp1_agg[, age := paste0("0-", gsub("1-(.+)","\\1",age_from1))]
    tmp1 = rbind( subset(tmp1, age %notin% c("0-1", age_from1)), tmp1_agg)
    data = rbind(subset(data, !code %in% loc), tmp1)
  }
  
  return(data)
}
