read_json = function(Date, state_name, state_code, data)
  {
  
  json_file <- file.path(path_to_data, Date, paste0(state_name, ".json"))
  json_data <- suppressWarnings(fromJSON(paste(readLines(json_file))))
  
  if(state_name == "florida") names(json_data) = gsub("(.+) years", "\\1",names(json_data))
  
  # age band's name changed 
  if(state_name == "arizona" & Date > as.Date("2020-05-13")) names(json_data) = unique(data$age)
  if(state_name == "missouri" & Date <= as.Date("2020-05-21")) names(json_data)[which(names(json_data) == "Under 20")] = "0-19"
  if(state_name == "missouri" & Date > as.Date("2020-05-21")) names(json_data)[which(names(json_data) == "under 20")] = "0-19"
  if(state_name == "missouri" & Date > as.Date("2020-07-06")) names(json_data)[which(names(json_data) == "0-19")] = "0-19"
  if(state_name == "pennsylvania" & Date > as.Date("2020-06-12")) names(json_data)[which(names(json_data) == "100+")] = ">100"
  if(state_name == "vermont" & Date > as.Date("2020-06-25")) names(json_data)[which(names(json_data) == "80+")] = "80 plus"
  
  # age bands were change and the limits between old and new age bands do not match
  if(state_name == "missouri" & Date < as.Date("2020-10-07")) names(json_data)[which(names(json_data) == "0-19")] = "0-17"
  if(state_name == "missouri" & Date < as.Date("2020-10-07")) names(json_data)[which(names(json_data) == "20-29")] = "18-29"
  if(state_name == "iowa" & Date < as.Date("2020-11-12")) names(json_data)[which(names(json_data) == "18-40")] = "18-39"
  if(state_name == "iowa" & Date < as.Date("2020-11-12")) names(json_data)[which(names(json_data) == "41-60")] = "40-59"
  if(state_name == "iowa" & Date < as.Date("2020-11-12")) names(json_data)[which(names(json_data) == "61-80")] = "60-79"
  if(state_name == "iowa" & Date < as.Date("2020-11-12")) names(json_data)[which(names(json_data) == ">80")] = "80+"
  
  # more age bands were introduced, aggregate to previous one to reconstruct the time series
  if(state_name == "missouri" & Date >= as.Date("2020-10-07")){
    json_data[['0-17']] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("0-4", "5-9", "10-14", "15-17"))])))
    json_data[["18-29"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("18-24", "25-29"))])))
    json_data[["30-39"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("30-34", "35-39"))])))
    json_data[["40-49"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("40-44", "45-49"))])))
    json_data[["50-59"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("50-54", "55-59"))])))
    json_data[["60-69"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("60-64", "65-69"))])))
    json_data[["70-79"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("70-74", "75-79"))])))
    json_data = json_data[-c(which(names(json_data) %in% c("0-4", "5-9", "10-14", "15-17","18-24", "25-29","30-34", "35-39",
                                   "40-44", "45-49","50-54", "55-59","60-64", "65-69","70-74", "75-79")))]
  }
  if(state_name == "minnesota" & Date >= as.Date("2020-08-20")){
    json_data[["20-29"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("20-24", "25-29"))])))
    json_data[["30-39"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("30-34", "35-39"))])))
    json_data[["40-49"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("40-44", "45-49"))])))
    json_data[["50-59"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("50-54", "55-59"))])))
    json_data[["60-69"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("60-64", "65-69"))])))
    json_data[["70-79"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("70-74", "75-79"))])))
    json_data[["80-89"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("80-84", "85-89"))])))
    json_data[["90-99"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("90-94", "95-99"))])))
    json_data = json_data[-c(which(names(json_data) %in% c("20-24", "25-29","30-34", "35-39","40-44", "45-49",
                                                           "50-54", "55-59","60-64", "65-69","70-74", "75-79",
                                                           "80-84", "85-89", "90-94", "95-99")))]
  }
  if(state_name == "iowa" & Date >= as.Date("2020-11-12")){
    json_data[["18-39"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("18-29", "30-39"))])))
    json_data[["40-59"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("40-49", "50-59"))])))
    json_data[["60-79"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("60-69", "70-79"))])))
    json_data = json_data[-c(which(names(json_data) %in% c("18-29", "30-39", "40-49", "50-59", "60-69", "70-79")))]
  }
  if(state_name == "nyc" & Date >= as.Date("2020-11-09")){
    json_data[["18-44"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("18-24", "25-34", "35-44"))])))
    json_data[["45-64"]] = sum(as.numeric(unlist(json_data[which(names(json_data) %in% c("45-54", "55-64"))])))
    json_data = json_data[-c(which(names(json_data) %in% c("18-24", "25-34", "35-44", "45-54", "55-64")))]
  }

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

fix_age_json = function(data, state_code)
  {
  data[, age := ifelse(age == "<1", "0-0", age)]
  data[, age := ifelse(age == "00-04", "0-4", age)]
  data[, age := ifelse(age == "05-17", "5-17", age)]
  data[, age := ifelse(age == "<10", "0-9", age)]
  data[, age := ifelse(age == "<18", "0-17", age)]
  data[, age := ifelse(age == "<19", "0-18", age)]
  data[, age := ifelse(age %in% c("<20","Under20"), "0-19", age)]
  data[, age := ifelse(age %in% c("80plus","80andover"), "80+", age)]
  data[, age := ifelse(age == ">80", "81+", age)]
  data[, age := ifelse(age == ">100", "100+", age)]
  data[, age := suppressWarnings(ifelse(grepl('to', age), paste0(as.numeric(gsub("(.+)to.*", "\\1", age)), "-", as.numeric(gsub(".*to(.+)", "\\1", age))), age))]
  
  if(state_code == "DC"){ # DC made a mistake in its age band, <19 includes 19
    data[, age := ifelse(age == "0-18", "0-19", age)]
  }
  if(state_code == "UT"){ # utah made a mistake in its age band, 0-1 is "Less than 1 year"
    data[, age := ifelse(age == "0-1", "0-0", age)]
  }
  if(state_code == "SC"){ # SC made a mistake in its age band, <10 includes 10
    data[, age := ifelse(age == "0-9", "0-10", age)]
  }
  
  #
  # Check that the first age group start at 0 - if not include a 0-(min(age)-1) with 0 deaths
  age_group_lower_bound = gsub("(.+)\\-.*", "\\1", unique(data$age))
  if("0" %notin% age_group_lower_bound){
    new_age_group = suppressWarnings(paste0("0-",as.character(  min(na.omit(as.numeric(age_group_lower_bound))) - 1) )) # there is one NA for the last age group age+
    data = rbind(data, data.table(age = new_age_group,
                                  date = unique(data$date),
                                  cum.deaths = 0,
                                  daily.deaths = c(NA_real_, rep(0, (length(unique(data$date))-1) )),
                                  code = unique(data$code))
    )
  }
  
  return(data)
}
