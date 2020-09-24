read_json = function(Date, state_name, state_code, data)
  {
  
  json_file <- file.path(path_to_data, Date, paste0(state_name, ".json"))
  json_data <- suppressWarnings(fromJSON(paste(readLines(json_file))))
  
  # age band's name changed with time
  if(state_name == "arizona" & Date > as.Date("2020-05-13")) names(json_data) = unique(data$age)
  if(state_name == "missouri" & Date > as.Date("2020-05-21")) names(json_data)[which(names(json_data) == "under 20")] = "Under 20"
  if(state_name == "missouri" & Date > as.Date("2020-07-06")) names(json_data)[which(names(json_data) == "0-19")] = "Under 20"
  if(state_name == "pennsylvania" & Date > as.Date("2020-06-12")) names(json_data)[which(names(json_data) == "100+")] = ">100"
  if(state_name == "vermont" & Date > as.Date("2020-06-25")) names(json_data)[which(names(json_data) == "80+")] = "80 plus"
  if(state_name == "florida") names(json_data) = gsub("(.+) years", "\\1",names(json_data))
  
  # make sure that there is no space in the age band name
  names(json_data) = gsub(" ", "", names(json_data), fixed = TRUE)
  
  # process the file
  tmp = data.table(age = names(json_data), 
                   cum.deaths = NA_integer_, 
                   daily.deaths = NA_integer_, 
                   code = state_code, 
                   date = Date)
  
  # remove unknown and total groups
  tmp = tmp[which(tmp$age != "Unknown"),]; tmp = tmp[which(tmp$age != "unknown"),]
  tmp = tmp[which(tmp$age != "total"),]; tmp = tmp[which(tmp$age != "Total"),]; tmp = tmp[which(tmp$age != "N"),]
  tmp = tmp[which(tmp$age != "Notavailable"),]; tmp = tmp[which(tmp$age != "Missing"),]
  
  return(list(json_data, tmp))
}

check_format_json = function(tmp, json_data, state_name, age_group, Date)
  {
  
  # sometimes mismatch in the place of the data on the json
  if(state_name == "nyc"){
    cum.deaths = suppressWarnings(as.numeric(gsub("(.+) \\(.*", "\\1", json_data[[age_group]][1])))
    if(is.na(cum.deaths)) cum.deaths = as.numeric(gsub("(.+) \\(.*\\(.*", "\\1", json_data[[age_group]][1])) 
    json_data[[age_group]] = cum.deaths
  }
  
  # data in percent
  if(state_name == "washington"){
    cum.deaths = as.numeric(gsub("(.+)\\%", "\\1", json_data[[age_group]][1])) * as.numeric(gsub(",", "", json_data[["total"]])) / 100
    json_data[[age_group]] = cum.deaths
  }
  if(state_name == "wyoming"){
    cum.deaths = as.numeric(gsub("(.+)\\%", "\\1", json_data[[age_group]][1])) * as.numeric(json_data[["total"]]) / 100
    json_data[[age_group]] = cum.deaths
  }
  
  # data changed from percentage to absolute value on this date
  if(state_name == "new_jersey" & Date < as.Date("2020-06-22")){ 
    cum.deaths = as.numeric(json_data[[age_group]][1]) * as.numeric(json_data[["N"]]) / 100
    json_data[[age_group]] = cum.deaths
  }
  
  # remove comma if any
  if(any(grepl(",", json_data[[age_group]]))){
    index_comma = which(grepl(",", json_data[[age_group]]) == T)
    json_data[[age_group]][index_comma] = as.numeric(gsub(",", "", json_data[[age_group]][index_comma]))
  }
  
  # remove signs such as "<" if any
  if(any(grepl("<", json_data[[age_group]]))){
    index_sign = which(grepl("<", json_data[[age_group]]) == T)
    json_data[[age_group]][index_sign] = 0
  }
  
  # index inside the json varies states by state
  index = 1
  if(state_name == "ma") index = 2
  
  cum.deaths = as.integer(json_data[[age_group]][index])
  tmp[which(age == age_group),]$cum.deaths = cum.deaths
  
  return(tmp)
}

modify_ageband = function(data, state_name, state_code)
{
  ## change age label for some states
  if(state_name == "delaware"){
    data = data %>%
      mutate(age = ifelse(age == "5-17", "5-19", 
                          ifelse(age =="18-34", "20-34", age)))
  }
  
  if(state_name == "arizona" | state_name == "illinois"){
    data = data %>%
      mutate(age = ifelse(age == "<20", "0-19", age))
  }
  
  if(state_name == "louisiana"){
    data = suppressWarnings(data %>%
                              mutate(age = ifelse(age == "<18", "0-19",
                                                  ifelse(age == "18-29", "20-29", age))))
  }
  
  if(state_name == "utah"){
    data = data.table( data )
    data_agg = data[age %in% c("0-1", "1-14"), list(cum.deaths = sum(cum.deaths),
                                                    daily.deaths = sum(daily.deaths)),
                    by = c("date", "code")]
    data_agg[, age := "0-14"]
    
    data = rbind( subset(data, age %notin% c("0-1", "1-14")), data_agg)
  }
  
  if(state_name == "iowa"){
    data = data %>%
      mutate(age = ifelse(age == "0-17", "0-19",
                          ifelse(age == "18-40", "20-39", 
                             ifelse(age == "41-60", "40-59",
                                    ifelse(age == "61-80", "60-79",
                                           "80+")))))
  }
  
  if(state_name == "missouri"){
    data = data %>%
      mutate(age = ifelse(age == "Under20", "0-19", age))
  }
  
  if(state_name == "SouthCarolina"){
    data = suppressWarnings(data %>%
                              mutate(age = ifelse(age == "81+", "80+", 
                                                  ifelse( age == "<10", "0-9", 
                                                          paste0(as.numeric(gsub("(.+)\\-.*", "\\1", age))-1, "-", as.numeric(gsub(".*\\-(.+)", "\\1", age))-1)))))
  }
  
  if(state_name == "oklahoma"){
    data = data %>%
      mutate(age = ifelse(age == "00-04", "0-4", 
                          ifelse(age == "05-17", "5-19",
                                 ifelse(age == "18-35", "20-34",
                                        ifelse(age == "36-49", "35-49", age)))))
  }
  
  if(state_name == "vermont"){
    data = data %>%
      mutate(age = ifelse(age == "80plus", "80+", age))
  }
  
  if(state_name == "california"){
    data = data %>%
      mutate(age = ifelse(age == "0-17", "0-19", 
                          ifelse(age == "18-49", "20-49", age)))
  }
  if(state_name == "alabama"){
    data = data %>%
      mutate(age = ifelse(age == "5-17", "5-19", 
                          ifelse(age == "18-24", "20-24", age)))
  }
  if(state_name == "NorthCarolina"){
    data = data %>%
      mutate(age = ifelse(age == "0-17", "0-19", 
                          ifelse(age == "18-24", "20-24", age)))
  }
  
  if(state_name == "mississippi"){
    data = data %>%
      mutate(age = ifelse(age == "<18", "0-19", 
                          ifelse(age == "18-29", "20-29", age)))
  }
  
  if(state_name == "wyoming"){
    data = data %>%
      mutate(age = ifelse(age == "0-18", "0-19", 
                          ifelse(age == "19-64", "20-64", age)))
  }
  if(state_name == "hawaii"){
    data = data %>%
      mutate(age = ifelse(age == "0-17", "0-19", 
                          ifelse(age == "18-29", "20-29", age)))
  }
  if(state_name == "nyc"){
    data = data %>%
      mutate(age = ifelse(age == "0-17", "0-19", 
                          ifelse(age == "18-44", "20-44", 
                                 ifelse(age == "65-76", "65-74", age))))
  }
  
  if(state_name == "pennsylvania"){
    data = data %>%
      mutate(age = ifelse(age == ">100", "100+", age))
  }
  
  if(state_name == "nevada"){
    data = data %>%
      mutate(age = ifelse(age == "<10", "0-9", age))
  }
  
  if(state_name == "new_jersey"){
    data = data %>%
      mutate(age = ifelse(age == "5-17", "5-19", 
                          ifelse(age == "18-29", "20-29",age)))
  }
  
  if(state_name == "kansas"){
    data = data %>%
      mutate(age = ifelse(age == "0-17", "0-19", 
                          ifelse(age == "18-24", "20-24",age)))
  }
  
  if(state_name == "doc"){
    data = data %>%
      mutate(age = ifelse(age == "<19", "0-19", age))
  }
  
  if(state_name == "oregon"){
    data = suppressWarnings(data %>%
                              mutate(age = ifelse(age == "80andover", "80+", 
                                                  paste0(as.numeric(gsub("(.+)to.*", "\\1", age)), "-", as.numeric(gsub(".*to(.+)", "\\1", age))))))
  }
  
  ## Check that the first age group start at 0 - if not include a 0-(min(age)-1) with 0 deaths
  age_group_lower_bound = gsub("(.+)\\-.*", "\\1", unique(data$age))
  if("0" %notin% age_group_lower_bound){
    new_age_group = paste0("0-",as.character(  min(na.omit(as.numeric(age_group_lower_bound))) - 1) ) # there is one NA for the last age group age+
    data = rbind(data, data.table(age = new_age_group,
                                  date = unique(data$date),
                                  cum.deaths = 0,
                                  daily.deaths = c(NA_real_, rep(0, (length(unique(data$date))-1) )),
                                  code = state_code)
    )
  }
  
  return(data)
}