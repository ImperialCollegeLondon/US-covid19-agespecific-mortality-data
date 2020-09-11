find_daily_deaths = function(dates, h_data, state_code)
{
  
  first.day = min(dates)

  data = NULL
  
  for(t in 1:length(dates)){
    
    Date = dates[t]
    print(Date)
    
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
          daily.deaths = round((cum.death.t_lag - cum.death.t_0 )/(n.lost.days+1))
          
          data = rbind(data, data.table(age = age_group, 
                                        date = lost.days, 
                                        cum.deaths = round(cum.death.t_0 + daily.deaths*c(1:n.lost.days)), 
                                        daily.deaths = rep(daily.deaths, n.lost.days), 
                                        code = state_code))
          
          #  if daily deaths rounded to 0
          if(daily.deaths == 0 & (cum.death.t_lag - cum.death.t_0) > 0){
            day.inc = which(round((cum.death.t_lag - cum.death.t_0 )/(1:(n.lost.days+1))) > 0)[1]
            daily.deaths = round((cum.death.t_lag - cum.death.t_0 )/day.inc) 
            data[date %in% (Date - 1:day.inc) & age == age_group,]$daily.deaths = daily.deaths
          }
          # if the sum of the rounding death is greater than the difference
          if(sum(rep(daily.deaths, n.lost.days+1)) > (cum.death.t_lag - cum.death.t_0)){
            day.inc = which(sapply(1:(n.lost.days+1), function(x) sum(rep(daily.deaths, x))) <= (cum.death.t_lag - cum.death.t_0))[1]
            if(day.inc != 1) data[date %in% (Date - c(n.lost.days:1)[-day.inc]) & age == age_group,]$daily.deaths = 0
            if(day.inc == 1) data[date %in% (Date - c(n.lost.days:1)) & age == age_group,]$daily.deaths = 0
          }
          
        }
        
        stopifnot(daily.deaths >= 0)
        
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

  
