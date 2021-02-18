adjust_to_5y_age_band = function(data)
{
  
  data = as.data.table( data )
  data[, age := as.character(age)]
  
  #
  # modify age band
  data[, age := ifelse(age == "0-5", "0-4", age)]
  data[, age := ifelse(age == "0-10", "0-9", age)]
  data[, age := ifelse(age == "0-17", "0-19", age)]
  data[, age := ifelse(age == "0-18", "0-19", age)]
  data[, age := ifelse(age == "5-17", "5-19", age)]
  data[, age := ifelse(age == "6-11", "5-9", age)]
  data[, age := ifelse(age == "10-17", "10-19", age)]
  data[, age := ifelse(age == "10-18", "10-19", age)]
  data[, age := ifelse(age == "11-20", "10-19", age)]
  data[, age := ifelse(age == "11-17", "10-19", age)]
  data[, age := ifelse(age == "12-14", "10-14", age)]
  data[, age := ifelse(age == "18-24", "20-24", age)]
  data[, age := ifelse(age == "18-29", "20-29", age)]
  data[, age := ifelse(age == "18-34", "20-34", age)]
  data[, age := ifelse(age == "18-35", "20-34", age)]
  data[, age := ifelse(age == "18-40", "20-39", age)]
  data[, age := ifelse(age == "18-44", "20-44", age)]
  data[, age := ifelse(age == "18-39", "20-39", age)]
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
  tmp = subset(data, age == "0-0")
  stopifnot( nrow(subset(data, age ==  "0-1")) == 0 )
  for(loc in unique(tmp$code)){
    tmp1 = subset(data, code == loc)
    age_from1 = unique(tmp1$age)[which(grepl('1-',unique(tmp1$age)))]
    tmp1_agg = tmp1[age %in% c("0-0", age_from1), list(cum.deaths = sum(cum.deaths),
                                                       daily.deaths = sum(daily.deaths)),
                    by = c("date", "code")]
    tmp1_agg[, age := paste0("0-", gsub("1-(.+)","\\1",age_from1))]
    tmp1 = rbind( subset(tmp1, age %notin% c("0-0", age_from1)), tmp1_agg)
    data = rbind(subset(data, !code %in% loc), tmp1)
  }
  
  # check
  data[, age_from := as.numeric(ifelse(grepl("\\+", age), gsub("(.+)\\+", "\\1", age), gsub("(.+)-.*", "\\1", age)))]
  data[, age_to := as.numeric(ifelse(grepl("\\+", age), 100, gsub(".*-(.+)", "\\1", age)))]
  stopifnot(all(unique(data$age_from) %%5 == 0) & all(str_sub(as.character(data$age_to), -1, -1) %in% c("0", "4", "9")))
  
  data = select(data, -c("age_from", "age_to"))
  
  return(data)
}

keep_days_match_JHU = function(data)
{
  #
  # include Texas from 27/07 (day where the data start matching with JHU)
  data_woTX = subset(data, code != "TX") 
  data_TX = subset(data, code == "TX" & date > as.Date("2020-07-27")) 
  data = dplyr::bind_rows(data_woTX, data_TX)
  rm(data_woTX, data_TX)
  
  #
  # include NYC from 30/06 (day where the data start matching with NYC overall)
  data_woNYC = subset(data, code != "NYC") 
  data_NYC = subset(data, code == "NYC" & date > as.Date("2020-06-30")) 
  data = dplyr::bind_rows(data_woNYC, data_NYC)
  rm(data_woNYC, data_NYC)
  
  #
  # include Vermont from 15/06 (day where the data start matching with JHU)
  data_woVT = subset(data, code != "VT") 
  data_VT = subset(data, code == "VT" & date > as.Date("2020-06-15")) 
  data = dplyr::bind_rows(data_woVT, data_VT)
  rm(data_woVT, data_VT)
  
  #
  # include Georgia from 8/05 (day where the data start matching with JHU)
  data_woGA = subset(data, code != "GA") 
  data_GA = subset(data, code == "GA" & date > as.Date("2020-05-08")) 
  data = dplyr::bind_rows(data_woGA, data_GA)
  rm(data_woGA, data_GA)
  
  #
  # include Idaho from 15/06 (day where the data start matching with JHU)
  data_woID = subset(data, code != "ID") 
  data_ID = subset(data, code == "ID" & date > as.Date("2020-06-15")) 
  data = dplyr::bind_rows(data_woID, data_ID)
  rm(data_woID, data_ID)
  
  #
  # include Kansas from 01/06 (day where the data start matching with JHU)
  data_woKS = subset(data, code != "KS") 
  data_KS = subset(data, code == "KS" & date > as.Date("2020-06-01")) 
  data = dplyr::bind_rows(data_woKS, data_KS)
  rm(data_woKS, data_KS)
  
  return(data)
}

adjust_delay_reporting = function(data)
{
  #
  # one day delay
  data_wo = subset(data, !code %in% states_w_one_day_delay)
  data_one_day_delay = subset(data, code %in% states_w_one_day_delay)
  data_one_day_delay[, date := date + 1]
  data = dplyr::bind_rows(data_wo, data_one_day_delay)
  rm(data_wo, data_one_day_delay)
  
  return(data)
}

`%notin%` = Negate(`%in%`)
