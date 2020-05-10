library("rjson")
library(readxl)
library(tidyverse)

path_to_data = "data"

obtain.nyc.data = function(first.day.nyc, last.day){
  cat("\n Processing New York City \n")
  dates = seq.Date(first.day.nyc, last.day, by = "day")
  data.nyc = NULL
  for(t in 1:length(dates)){
    Date = dates[t]
    json_file <- file.path(path_to_data, Date, "nyc.json")
    nyc_data <- suppressWarnings(fromJSON(paste(readLines(json_file))))
    tmp = data.table(age = names(nyc_data), cum.deaths = NA_integer_, daily.deaths = NA_integer_, 
                     code = "NYC", date = Date)
    tmp = tmp[-which(age == "unknown"),]
    for(age_group in tmp$age){
      cum.deaths= suppressWarnings(as.numeric(gsub("(.+) \\(.*", "\\1", nyc_data[[age_group]][1])))
      if(is.na(cum.deaths)) cum.deaths = as.numeric(gsub("(.+) \\(.*\\(.*", "\\1", nyc_data[[age_group]][1])) # sometimes mismatch
      stopifnot(is.numeric(cum.deaths))
      tmp[which(age == age_group),]$cum.deaths = cum.deaths
      if(Date > first.day.nyc){
        cum.death.t_1 = tmp[which(age == age_group & date == Date),]$cum.deaths
        cum.death.t_0 =  data.nyc[which(data.nyc$age == age_group & data.nyc$date == (Date-1)),]$cum.deaths
        daily.deaths = cum.death.t_1 - cum.death.t_0 
        stopifnot(is.numeric(daily.deaths))
        tmp[which(age == age_group & date == Date),]$daily.deaths = daily.deaths
      }
    }
    data.nyc = rbind(data.nyc, tmp)
  }
  return(data.nyc)
}

.obtain.nj.data = function(first.day.nj, last.day){
  dates = seq.Date(first.day.nj, last.day, by = "day")
  data.nj = NULL
  for(t in 1:length(dates)){
    Date = dates[t]
    json_file <- file.path(path_to_data, Date, "new_jersey.json")
    nj_data <- suppressWarnings(fromJSON(paste(readLines(json_file))))
    tmp = data.table(age = names(nj_data), cum.deaths = NA_integer_, daily.deaths = NA_integer_, 
                     code = "NJ", date = Date)
    for(age_group in tmp$age){
      cum.deaths = suppressWarnings(as.numeric(gsub("(.+) .*", "\\1", nj_data[[age_group]][1])))
      stopifnot(is.numeric(cum.deaths))
      tmp[which(age == age_group),]$cum.deaths = cum.deaths
      if(Date > first.day.nj){
        cum.death.t_1 = tmp[which(age == age_group & date == Date),]$cum.deaths
        cum.death.t_0 =  data.nj[which(data.nj$age == age_group & data.nj$date == (Date-1)),]$cum.deaths
        daily.deaths = cum.death.t_1 - cum.death.t_0 
        stopifnot(is.numeric(daily.deaths))
        tmp[which(age == age_group & date == Date),]$daily.deaths = daily.deaths
      }
    }
    data.nj = rbind(data.nj, tmp)
  }
  return(data.nj)
}

obtain.fl.data = function(first.day.fl, last.day){
  cat("\n Processing Florida \n")
  
  dates = seq.Date(first.day.fl, last.day, by = "day")
  data.fl = NULL
  for(t in 1:length(dates)){
    Date = dates[t] 
    json_file <- file.path(path_to_data, Date, "florida.json")
    fl_data <- suppressWarnings(fromJSON(paste(readLines(json_file))))
    tmp = data.table(age = names(fl_data), cum.deaths = NA_integer_, daily.deaths = NA_integer_, 
                     code = "FL", date = Date)
    for(age_group in tmp$age){
      cum.deaths= as.numeric(fl_data[[age_group]][1])
      stopifnot(is.numeric(cum.deaths))
      tmp[which(age == age_group),]$cum.deaths = cum.deaths
      if(Date > first.day.fl){
        cum.death.t_1 = tmp[which(age == age_group & date == Date),]$cum.deaths
        cum.death.t_0 =  data.fl[which(data.fl$age == age_group & data.fl$date == (Date-1)),]$cum.deaths
        daily.deaths = cum.death.t_1 - cum.death.t_0 
        stopifnot(is.numeric(daily.deaths))
        tmp[which(age == age_group & date == Date),]$daily.deaths = daily.deaths
      }
    }
    data.fl = rbind(data.fl, tmp)
  }
  return(data.fl)
}

obtain.wa.data = function(last.monday){
  cat("\n Processing Washington \n")
  
    xlsx_file = file.path(path_to_data, last.monday, "washington.xlsx")
    tmp = read_excel(xlsx_file, sheet = "Deaths")
    data.wa = select(tmp, -c("Deaths", "dtm_updated", "Positive UnkAge")) %>%
      reshape2::melt(id.vars = c("County", "WeekStartDate")) %>%
      group_by(WeekStartDate, variable) %>%
      summarise(weekly.deaths = sum(value)) %>%
      mutate(age = gsub("Age (.+)", "\\1",variable),
             code = "WA") %>%
      select(WeekStartDate, age, weekly.deaths, code)
    return(data.wa)
}

obtain.tx.data = function(first.day.tx, last.day){
  cat("\n Processing Texas \n")
  dates = seq.Date(first.day.tx, last.day, by = "day")
  data.tx = NULL
  for(t in 1:length(dates)){
    Date = dates[t]
    xlsx_file = file.path(path_to_data, Date, "texas.xlsx")
    tmp = read_excel(xlsx_file, sheet = "Fatalities by Age Group", col_names = c("age", "cum.deaths", "perc"))
    tmp = tmp[-c(1:2, 15:19), 1:2]
    tmp = tmp %>%
      mutate(age = ifelse(age == "<1 year", "0-1", gsub("(.+) years", "\\1", age)),
             code = "TX", 
             date = Date,
             cum.deaths = as.numeric(cum.deaths), 
             daily.deaths = NA_integer_)
    if(Date > first.day.tx){
      cum.death.t_1 = tmp[which(tmp$date == Date),]$cum.deaths
      cum.death.t_0 =  data.tx[which(data.tx$date == (Date-1)),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0 
      stopifnot(is.numeric(daily.deaths))
      tmp[which(tmp$date == Date),]$daily.deaths = daily.deaths
    }
    data.tx = rbind(data.tx, tmp)
  }
  return(data.tx)
}

obtain.ga.data = function(first.day.ga, last.day){
  cat("\n Processing Georgia \n")
  
  dates = seq.Date(first.day.ga, last.day, by = "day")
  data.ga = NULL
  for(t in 1:length(dates)){
    Date = dates[t]
    csv_file = file.path(path_to_data, Date, "georgia.csv")
    tmp = read.csv(csv_file)
    tmp = subset(tmp, !is.na(age))
    agedf = data.table(age = 0:max(101,max(tmp$age)))
    tmp = as.data.table(tmp) %>%
      group_by(age) %>%
      summarise(cum.deaths = n()) %>%
      merge(agedf, by = "age", all.y = T) %>%
      mutate(date = Date,
             code = "GA",
             daily.deaths = NA_integer_)
    tmp[is.na(tmp$cum.deaths),]$cum.deaths = 0
    if(Date > first.day.ga){
      cum.death.t_1 = tmp[which(tmp$date == Date),]$cum.deaths
      cum.death.t_0 =  data.ga[which(data.ga$date == (Date-1)),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0 
      stopifnot(is.numeric(daily.deaths))
      tmp[which(tmp$date == Date),]$daily.deaths = daily.deaths
    }
    data.ga = rbind(data.ga, tmp)
  }
  return(data.ga)
}

obtain.cdc.data = function(first.day.cdc, last.wednesday){
  cat("\n Processing CDC \n")
  
  dates = seq.Date(first.day.cdc, last.wednesday, by = "week")
  states = c("California", "Connecticut", "Colorado", "Illinois", "Indiana", "Louisiana", "Massachusetts","Maryland","Michigan","New Jersey", 
             "Pennsylvania", "Texas", "Florida", "Georgia", "New York", "Ohio", "Washington")
  coderef = data.table(code = c("CA", "CT", "CO", "IL", "IN", "LA", "MA", "MD", "MI", "NJ", "PA", "TX", "FL", "GA", "NY", "OH", "WA"), State = states)
  data.cdc = NULL
  for(t in 1:length(dates)){
    Date = dates[t]
    csv_file = file.path(path_to_data, Date, "cdc.csv")
    tmp = read.csv(csv_file)
    tmp = select(tmp, c("Start.week", "End.Week", "State", "Age.group", "COVID.19.Deaths")) %>%
      subset(State %in% states & Age.group != "Male, all ages" & Age.group != "Female, all ages" & Age.group != "All ages") %>%
      mutate(age = ifelse(Age.group == "85 years and over", "85+",
                          ifelse(Age.group == "Under 1 year", "0-1", gsub("(.+) years", "\\1", Age.group)))) %>%
      group_by(Start.week, End.Week, State, age) %>%
      summarise(cum.deaths = sum(COVID.19.Deaths)) %>%
      merge(coderef, by = "State") %>%
      mutate(daily.deaths = NA_integer_)
    tmp[is.na(tmp$cum.deaths),]$cum.deaths = 0
    if(Date > first.day.cdc){
      for(state in states){
        for(Age in tmp$age){
          cum.death.t_1 = tmp[which(tmp$date == Date & tmp$State == state & tmp$age == Age),]$cum.deaths
          cum.death.t_0 =  data.ga[which(data.ga$date == (Date-1)& data.ga$State == state & data.ga$age == Age),]$cum.deaths
          daily.deaths = cum.death.t_1 - cum.death.t_0 
          stopifnot(is.numeric(daily.deaths))
          tmp[which(tmp$date == Date& tmp$State == state& tmp$age == Age),]$daily.deaths = daily.deaths 
        }
      }
    }
    data.cdc = rbind(data.cdc, tmp)
  }
  return(data.cdc)
}
