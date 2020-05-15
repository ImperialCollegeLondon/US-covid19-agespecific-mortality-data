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
  
  # Reorder data
  data.nyc <- with(data.nyc, data.nyc[order(date, age, cum.deaths, daily.deaths, code), ])
  data.nyc <- data.nyc[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
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
  
  dates = dates[-which(dates == as.Date("2020-05-09"))] # no report on this day
  
  data.fl = NULL
  for(t in 1:length(dates)){
    Date = dates[t] 
    json_file <- file.path(path_to_data, Date, "florida.json")
    fl_data <- suppressWarnings(fromJSON(paste(readLines(json_file))))
    tmp = data.table(age = gsub("(.+) years", "\\1",names(fl_data)), cum.deaths = NA_integer_, daily.deaths = NA_integer_, 
                     code = "FL", date = Date)
    for(age_group in tmp$age){
      cum.deaths = as.numeric(fl_data[[paste(age_group, "years")]][1])
      stopifnot(is.numeric(cum.deaths))
      tmp[which(age == age_group),]$cum.deaths = cum.deaths
      if(Date > first.day.fl){
        cum.death.t_1 = tmp[which(age == age_group & date == Date),]$cum.deaths
        cum.death.t_0 =  data.fl[which(data.fl$age == age_group & data.fl$date == (Date-1)),]$cum.deaths
        daily.deaths = cum.death.t_1 - cum.death.t_0 
        if(Date == as.Date("2020-05-10")){
          cum.death.t_1_2 = tmp[which(age == age_group & date == Date),]$cum.deaths
          cum.death.t_0 =  data.fl[which(data.fl$age == age_group & data.fl$date == (Date-2)),]$cum.deaths
          daily.deaths = round((cum.death.t_1_2 - cum.death.t_0 )/2)
          # cum death are divided equally among the last two days
          data.fl = rbind(data.fl, data.table(age = age_group, date = (Date-1), cum.deaths = round(cum.death.t_1_2/2), daily.deaths = daily.deaths, code = "FL"))
          tmp[which(age == age_group & date == Date),]$cum.deaths = round(cum.death.t_1_2/2)
        }
        stopifnot(is.numeric(daily.deaths))
        if(daily.deaths<0){
          data.fl[which(data.fl$age == age_group & data.fl$date == (Date-1)),]$cum.deaths = cum.death.t_0 + daily.deaths
          daily.deaths = 0
        }
        tmp[which(age == age_group & date == Date),]$daily.deaths = daily.deaths
      }
    }
    data.fl = rbind(data.fl, tmp)
  }
  
  # Reorder data
  data.fl <- with(data.fl, data.fl[order(date, age, cum.deaths, daily.deaths, code), ])
  data.fl <- data.fl[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
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
      select(WeekStartDate, age, weekly.deaths, code) %>%
      rename(date = WeekStartDate)
    
    # Reorder data
    data.wa <- with(data.wa, data.wa[order(date, age, weekly.deaths, code), ])
    data.wa <- data.wa[, c("date", "age", "weekly.deaths", "code")]
    
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
      mutate(age = ifelse(age == "<1 year", "0-9", 
                          ifelse(age == "1-9 years", "0-9", gsub("(.+) years", "\\1", age))), # group 0-1 and 2-9 for analysis
             code = "TX", 
             date = Date,
             cum.deaths = as.numeric(cum.deaths), 
             daily.deaths = NA_integer_) %>%
      group_by(age, code, date, daily.deaths) %>%
      summarise(cum.deaths = sum(cum.deaths))
    
    if(Date > first.day.tx){
      cum.death.t_1 = tmp[which(tmp$date == Date),]$cum.deaths
      cum.death.t_0 =  data.tx[which(data.tx$date == (Date-1)),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0 
      stopifnot(is.numeric(daily.deaths))
      tmp[which(tmp$date == Date),]$daily.deaths = daily.deaths
  }
    data.tx = rbind(data.tx, tmp)
  }
  # Reorder data
  data.tx <- with(data.tx, data.tx[order(date, age, cum.deaths, daily.deaths, code), ])
  data.tx <- data.tx[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
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
    tmp = subset(tmp, !is.na(age) & age != ".")
    agedf = data.table(age = 0:109, age_cat = cut(0:109, breaks = seq(0, 110, 5), include.highest = FALSE, right = FALSE))
    
    if(Date >= as.Date("2020-05-12")){ # age groups change on this date
      tmp$age = as.character(tmp$age)
      tmp[which(tmp$age == "90+"),]$age = "90"
      tmp$age = as.numeric(tmp$age)
    }
    
    tmp = as.data.table(tmp) %>%
      merge(agedf, by = "age", all.y = T) %>%
      mutate(age = ifelse(age_cat %in% c("[90,95)", "[95,100)", "[100,105)", "[105,110)"), "90+",
                          paste0(as.numeric(gsub("\\[(.+),.*", "\\1", age_cat)), "-", as.numeric( sub("[^,]*,([^]]*)\\)", "\\1", age_cat))-1))) %>%
      group_by(age) %>%
      summarise(cum.deaths = n()) %>%
      mutate(date = Date,
             code = "GA",
             daily.deaths = NA_integer_) %>%
      select(age, cum.deaths, daily.deaths, code, date)
    tmp[is.na(tmp$cum.deaths),]$cum.deaths = 0
    
    if(Date > first.day.ga){
      cum.death.t_1 = tmp[which(tmp$date == Date),]$cum.deaths
      cum.death.t_0 =  data.ga[which(data.ga$date == (Date-1)),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0 
      stopifnot(is.numeric(daily.deaths))
      if(any(daily.deaths<0)){
        index = which(daily.deaths<0)
        data.ga[which(data.ga$date == (Date-1)),]$cum.deaths[index] = cum.death.t_0[index] + daily.deaths[index]
        daily.deaths[index] = 0
      }
      tmp[which(tmp$date == Date),]$daily.deaths = daily.deaths
    }
    data.ga = rbind(data.ga, tmp)
  }
  
  # remove age > 100 for analysis
  data.ga <- subset(data.ga, age != "100-104" & age != "105-109")
  # Reorder data
  data.ga <- with(data.ga, data.ga[order(date, age, cum.deaths, daily.deaths, code), ])
  data.ga <- data.ga[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
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
                          ifelse(Age.group == "Under 1 year", "0-1", gsub("(.+) years", "\\1", Age.group))),
             date = as.Date(End.Week, format = "%m/%d/%y")) %>%
      group_by(date, State, age) %>%
      summarise(cum.deaths = sum(COVID.19.Deaths)) %>%
      merge(coderef, by = "State") %>%
      mutate(daily.deaths = NA_integer_) %>%
      rename(state = State) %>%
      select(state, date, age, cum.deaths, daily.deaths, code)
    tmp[is.na(tmp$cum.deaths),]$cum.deaths = 0
    
    if(Date > first.day.cdc){
      for(State in states){
        for(Age in tmp$age){
          cum.death.t_1 = tmp[which(tmp$date == Date & tmp$state == State & tmp$age == Age),]$cum.deaths
          cum.death.t_0 =  data.cdc[which(data.cdc$date == (Date-7) & data.cdc$state == State & data.cdc$age == Age),]$cum.deaths
          daily.deaths = cum.death.t_1 - cum.death.t_0 
          stopifnot(is.numeric(daily.deaths))
          tmp[which(tmp$date == Date & tmp$state == State & tmp$age == Age),]$daily.deaths = daily.deaths 
        }
      }
    }
    data.cdc = rbind(data.cdc, tmp)
  }
  
  # Reorder data
  data.cdc <- with(data.cdc, data.cdc[order(date, state, code, age, cum.deaths, daily.deaths), ])
  data.cdc <- data.cdc[, c("date", "state", "code", "age", "cum.deaths", "daily.deaths")]
  
  return(data.cdc)
}

obtain.ct.data = function(last.day){
  cat("\n Processing Connecticut \n")
  
  csv_file = file.path(path_to_data, last.day, "connecticut.csv")
 
  tmp = read.csv(csv_file) %>%
    mutate(AgeGroups = as.character(AgeGroups),
           age = ifelse(AgeGroups == "0 - 9", "0-9",
                        ifelse(AgeGroups == "10 -19" | AgeGroups == "19-Oct", "10-19",
                               ifelse(AgeGroups == "20 -29", "20-29",
                                      ifelse(AgeGroups == "30 - 39", "30-39",
                                             ifelse(AgeGroups == "40 -49", "40-49",
                                                    ifelse(AgeGroups == "50 -59", "50-59", 
                                                           ifelse(AgeGroups == "60 - 69", "60-69",
                                                                  ifelse(AgeGroups == "70 - 79", "70-79",
                                                                         ifelse(AgeGroups == "80 and older", "80+", AgeGroups))))))))),
           date = as.Date(DateUpdated, format = "%m/%d/%y"),
           code = "CT", 
           daily.deaths = NA_integer_) %>%
    rename(cum.deaths = Deaths) %>%
    select(age, date, code, cum.deaths, daily.deaths)
  for(t in 1:(length(unique(tmp$date))-1)){
    for(Age in unique(tmp$age)){
      Date = sort(unique(tmp$date))[-1][t]
      cum.death.t_1 = tmp[which(tmp$date == Date & tmp$age == Age),]$cum.deaths
      cum.death.t_0 = tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0 
      stopifnot(is.numeric(daily.deaths))
      if(daily.deaths < 0){
        tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$cum.deaths = cum.death.t_0 + daily.deaths
        daily.deaths = 0
        }
      tmp[which(tmp$date == Date & tmp$age == Age),]$daily.deaths = daily.deaths 
    }
  }
  
  # Reorder data
  data.ct <- with(tmp, tmp[order(date, code, age, cum.deaths, daily.deaths), ])
  data.ct <- data.ct[, c("date", "code", "age", "cum.deaths", "daily.deaths")]
  
return(data.ct)
}

obtain.co.data = function(last.day){
  cat("\n Processing Colorado \n")
  
  csv_file = file.path(path_to_data, last.day, "colorado.csv")
  
  tmp = read.csv(csv_file)
  tmp$rep_date = as.Date(tmp$rep_date, format = "%m/%d/%y")
  df = tmp[grepl(", Deaths", tmp$attribute),] %>%
    mutate(age = gsub("(.+), Deaths", "\\1", attribute)) %>%
    rename(date = rep_date, cum.deaths = value) %>%
    select(age, date, cum.deaths) 
  
  df2 = df %>%
    mutate(age = factor(age, levels = c("0-9", as.character(unique(df$age))))) %>%
    complete(age, date, fill = list(cum.deaths= 0)) %>%
    mutate(daily.deaths = NA_integer_, 
           code = "CO",
           age = as.character(age))
  
  for(t in 2:length(unique(df2$date))){
    for(a in 1:length(unique(df2$age))){
      Date = unique(df2$date)[t]; Age = unique(df2$age)[a]
      cum.deaths.t1 = df2[which(df2$date == Date & df2$age == Age),]$cum.deaths
      cum.deaths.t0 = df2[which(df2$date == (Date-1) & df2$age == Age),]$cum.deaths
      daily.deaths = cum.deaths.t1 - cum.deaths.t0
      stopifnot(is.numeric(daily.deaths))
      if(daily.deaths < 0){
        df2[which(df2$date == (Date-1)),]$cum.deaths = cum.deaths.t0 + daily.deaths
        daily.deaths = 0
      }
      df2[which(df2$date == Date & df2$age == Age),]$daily.deaths = cum.deaths.t1 - cum.deaths.t0
    }
  }
  
  # remove unknown age
  df2 <- subset(df2, age != "Unknown")
  # Reorder data
  data.co <- with(df2, df2[order(date, code, age, cum.deaths, daily.deaths), ])
  data.co <- data.co[, c("date", "code", "age", "cum.deaths", "daily.deaths")]

  return(data.co)
}

obtain.id.data = function(first.day.id, last.day){
  cat("\n Processing Idaho \n")
  
  dates = seq.Date(first.day.id, last.day, by = "day")
  
  data.id = NULL
  for(t in 1:length(dates)){
    Date = dates[t]
    csv_file = file.path(path_to_data, Date, "Idaho.csv")
    tmp = read.csv(csv_file)  %>%
      mutate(age = ifelse(Age.Group.Ten == "<18", "0-19", 
                          ifelse(Age.Group.Ten == "18-29 years", "20-29", Age.Group.Ten)), # group 0-1 and 2-9 for analysis
             code = "ID", 
             date = Date,
             cum.deaths = as.numeric(Deaths), 
             daily.deaths = NA_integer_) %>%
      group_by(age, code, date, daily.deaths) 
    
    if(Date > first.day.id){
      cum.death.t_1 = tmp[which(tmp$date == Date),]$cum.deaths
      cum.death.t_0 =  data.id[which(data.id$date == (Date-1)),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0 
      stopifnot(is.numeric(daily.deaths))
      tmp[which(tmp$date == Date),]$daily.deaths = daily.deaths
    }
    data.id = rbind(data.id, tmp)
  }
  # Reorder data
  data.id <- with(data.id, data.id[order(date, age, cum.deaths, daily.deaths, code), ])
  data.id <- data.id[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
  return(data.id)
}

obtain.json.data = function(first.day, last.day, state_name, state_code){
  cat(paste0("\n Processing ", state_name,"\n"))
  
  dates = seq.Date(first.day, last.day, by = "day")
  
  data = NULL
  for(t in 1:length(dates)){
    Date = dates[t]
    json_file <- file.path(path_to_data, Date, paste0(state_name, ".json"))
    json_data <- suppressWarnings(fromJSON(paste(readLines(json_file))))
    tmp = data.table(age = names(json_data), cum.deaths = NA_integer_, daily.deaths = NA_integer_, 
                     code = state_code, date = Date)
    tmp = tmp[which(tmp$age != "Unknown"),]; tmp = tmp[which(tmp$age != "unknown"),]
    
    for(age_group in tmp$age){
      if(grepl(",", json_data[[age_group]])) json_data[[age_group]] = as.numeric(gsub(",", "", json_data[[age_group]]))
      cum.deaths = as.integer(json_data[[age_group]])[1]
      tmp[which(age == age_group),]$cum.deaths = cum.deaths
      if(Date > first.day){
        cum.death.t_1 = tmp[which(age == age_group & date == Date),]$cum.deaths
        cum.death.t_0 =  data[which(data$age == age_group & data$date == (Date-1)),]$cum.deaths
        daily.deaths = cum.death.t_1 - cum.death.t_0 
        stopifnot(is.numeric(daily.deaths))
        tmp[which(age == age_group & date == Date),]$daily.deaths = daily.deaths
      }
    }
    data = rbind(data, tmp)
  }
  
  # Reorder data
  data <- with(data, data[order(date, age, cum.deaths, daily.deaths, code), ])
  data <- data[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
  # change age label for some states
  if(state_name == "delaware"){
    data = data %>%
      mutate(age = ifelse(age == "5-17", "5-19", 
                          ifelse(age =="18-34", "20-34", age)))
  }
  
  if(state_name == "arizona"){
    data = data %>%
      mutate(age = ifelse(age == "<20", "0-19", age))
  }
  
  if(state_name == "louisiana"){
    data = data %>%
      mutate(age = ifelse(age == "70+", age,
                          ifelse(age == "< 18", "0-19",
                                 ifelse(age == "18 - 29", "20-29",
                                        paste0(gsub("(.+) \\-.*", "\\1", age), "-",gsub(".*\\- (.+)", "\\1", age))))))
      
  }
  
  if(state_name == "iowa"){
    data = data %>%
      mutate(age = ifelse(age == "18-40", "19-39", 
                          ifelse(age == "41-60", "40-59",
                                 ifelse(age == "61-80", "59-79",
                                        "80+"))))
  }
  
  if(state_name == "missouri"){
    data = data %>%
      mutate(age = ifelse(age == "Under 20", "0-19", age))
  }
  
  if(state_name == "SouthCarolina"){
    data = data %>%
      mutate(age = ifelse(age == "81+", "80+", 
                          paste0(as.numeric(gsub("(.+)\\-.*", "\\1", age))-1, "-", as.numeric(gsub(".*\\-(.+)", "\\1", age))-1)))
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
      mutate(age = ifelse(age == "80 plus", "80+", age))
  }
  
  return(data)
}


