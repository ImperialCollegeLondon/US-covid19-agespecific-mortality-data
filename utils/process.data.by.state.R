library("rjson")
library(readxl)
library(tidyverse)

path_to_data = "data"

## STATES WITH RULE BASED FUNCTION
# obtain.CDC.data = function(last.day){
#   cat("\n Processing CDC \n")
#   
#   dates = seq.Date(as.Date("2020-03-22"), last.day, by = "week")
#   
#   data_files = list.files(file.path(path_to_data, dates), full.names = T)
#   data_files_state = data_files[grepl(paste0("cdc", ".csv"), data_files)]
#   dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
#   first.day = min(dates)
#   
#   states = c("California", "Connecticut", "Colorado", "Illinois", "Indiana", "Louisiana", "Massachusetts","Maryland","Michigan","New Jersey", 
#              "Pennsylvania", "Texas", "Florida", "Georgia", "New York", "Ohio", "Washington")
#   coderef = data.table(code = c("CA", "CT", "CO", "IL", "IN", "LA", "MA", "MD", "MI", "NJ", "PA", "TX", "FL", "GA", "NY", "OH", "WA"), State = states)
#   
#   data.cdc = NULL
#   for(t in 1:length(dates)){
#     Date = dates[t]
#     
#     csv_file = file.path(path_to_data, Date, "cdc.csv")
#     tmp = read.csv(csv_file)
#     tmp = select(tmp, c("Start.week", "End.Week", "State", "Age.group", "COVID.19.Deaths")) %>%
#       subset(State %in% states & Age.group != "Male, all ages" & Age.group != "Female, all ages" & Age.group != "All ages") %>%
#       mutate(age = ifelse(Age.group == "85 years and over", "85+",
#                           ifelse(Age.group == "Under 1 year", "0-1", gsub("(.+) years", "\\1", Age.group))),
#              date = as.Date(End.Week, format = "%m/%d/%y")) %>%
#       group_by(date, State, age) %>%
#       summarise(cum.deaths = sum(COVID.19.Deaths)) %>%
#       merge(coderef, by = "State") %>%
#       mutate(daily.deaths = NA_integer_) %>%
#       rename(state = State) %>%
#       select(state, date, age, cum.deaths, daily.deaths, code)
#     tmp[is.na(tmp$cum.deaths),]$cum.deaths = 0
#     
#     if(Date > first.day){
#       for(State in states){
#         for(Age in tmp$age){
#           cum.death.t_1 = tmp[which(tmp$date == Date & tmp$state == State & tmp$age == Age),]$cum.deaths
#           cum.death.t_0 =  data.cdc[which(data.cdc$date == (Date-7) & data.cdc$state == State & data.cdc$age == Age),]$cum.deaths
#           daily.deaths = cum.death.t_1 - cum.death.t_0 
#           stopifnot(is.numeric(daily.deaths))
#           tmp[which(tmp$date == Date & tmp$state == State & tmp$age == Age),]$daily.deaths = daily.deaths 
#         }
#       }
#     }
#     data.cdc = rbind(data.cdc, tmp)
#   }
#   
#   # Reorder data
#   data.cdc <- with(data.cdc, data.cdc[order(date, state, code, age, cum.deaths, daily.deaths), ])
#   data.cdc <- data.cdc[, c("date", "state", "code", "age", "cum.deaths", "daily.deaths")]
#   
#   return(data.cdc)
# }

process.TX.file = function(xlsx_file, Date){
  
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
  
  return(tmp)
}

process.GA.file = function(csv_file, Date){
  
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
  
  
  return(tmp)
}

process.ID.file = function(csv_file, Date){
  tmp = read.csv(csv_file) %>%
    mutate(age = ifelse(Age.Group.Ten == "<18", "0-19", 
                        ifelse(Age.Group.Ten == "18-29 years" | Age.Group.Ten == "18-29", "20-29", as.character(Age.Group.Ten))), # group 0-1 and 2-9 for analysis
           code = "ID", 
           date = Date,
           cum.deaths = as.numeric(Deaths), 
           daily.deaths = NA_integer_) %>%
    select(age, code, date, daily.deaths, cum.deaths) 
  
  return(tmp)  
}

process.AK.file = function(csv_file, Date){
  
  tmp = subset(read.csv(csv_file), grepl("Years", Demographic)) %>%
    mutate(age = gsub("(.+) Years", "\\1", ifelse(Demographic == "<10 Years", "0-9 Years", as.character(Demographic))),
           code = "AK", 
           date = Date,
           is_after_0622 = date > as.Date("2020-06-22"),
           cum.deaths = ifelse(is_after_0622, as.numeric(Deceased_Cases), as.numeric(Deaths)), # name of death variable changed on this date
           daily.deaths = NA_integer_) %>%
    select(age, code, date, daily.deaths, cum.deaths) 
  
  return(tmp)
  
}

process.RI.file = function(csv_file, Date){
  
  tmp = read.csv(csv_file)
  colnames(tmp)[1] = "age"
  tmp = as.data.frame(suppressWarnings(tmp[6:16,] %>%
                                         mutate(code = "RI", 
                                                date = Date,
                                                cum.deaths = ifelse(grepl("<", Deaths), 0, as.numeric(as.character(Deaths))), 
                                                daily.deaths = NA_integer_) %>%
                                         select(age, code, date, daily.deaths, cum.deaths) ))
  
  return(tmp)
}

obtain.data.csv_and_xlsx = function(last.day, state_name, state_code){
  cat("\n Processing", state_name,  "\n")
  
  dates = seq.Date(as.Date("2020-03-22"), last.day, by = "day")
  
  file_format = ".csv"
  if(state_code %in% c("TX")) file_format = ".xlsx"
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0(state_name, file_format), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  first.day = min(dates)

  data = NULL
  for(t in 1:length(dates)){
    Date = dates[t]
    print(Date)
    
    file = file.path(path_to_data, Date, paste0(state_name, file_format))
    tmp = do.call(paste0("process.", state_code, ".file"), list(file, Date))
    
    if(Date > first.day){
      cum.death.t_1 = tmp[which(tmp$date == Date),]$cum.deaths
      cum.death.t_0 =  data[which(data$date == (Date-1)),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0
      
      if((Date-1) %notin% dates){
        n.lost.days = as.numeric(Date - dates[which(dates == Date)-1])-1
        lost.days = Date - c(n.lost.days:1)
        
        for(age_group in tmp$age){
          cum.death.t_lag = tmp[which(tmp$date == Date & tmp$age == age_group),]$cum.deaths
          cum.death.t_0 = data[which(data$date == (Date-n.lost.days-1) & data$age == age_group ),]$cum.deaths
          daily.deaths = round((cum.death.t_lag - cum.death.t_0 )/(n.lost.days+1))
          
          stopifnot(is.numeric(daily.deaths))
          
          if( daily.deaths < 0 ) {
            daily.deaths = 0
            data[which(data$date == (Date-n.lost.days-1) & data$age == age_group),]$daily.deaths = 
              max(0, data[which(data$date == (Date-n.lost.days-1)& data$age == age_group),]$daily.deaths + daily.deaths)
          }
          # cum death are divided equally among the last two days
          data = dplyr::bind_rows(data, data.table(age = as.character(age_group), 
                                                         date = as.Date(lost.days), 
                                                         cum.deaths = round(cum.death.t_0 + daily.deaths*c(1:n.lost.days)), 
                                                         daily.deaths = rep(daily.deaths, n.lost.days), code = state_code)) 
          
          tmp[which(tmp$date == Date & tmp$age == age_group ),]$daily.deaths = daily.deaths
          tmp[which(tmp$date == Date & tmp$age == age_group ),]$cum.deaths = daily.deaths + data[which(data$date == (Date-1) & data$age == age_group ),]$cum.deaths
          
        }
        
      } else{
      
        stopifnot(is.numeric(daily.deaths))
        if(any(daily.deaths<0)){
          index = which(daily.deaths<0)
          data[which(data$date == (Date-1)),]$daily.deaths[index] = sapply(data[which(data$date == (Date-1)),]$daily.deaths[index] + daily.deaths[index], function(x) max(x,0))
          daily.deaths[index] = 0
          
        }
        tmp[which(tmp$date == Date),]$daily.deaths = daily.deaths
        tmp[which(tmp$date == Date),]$cum.deaths = daily.deaths + data[which(data$date == (Date-1)),]$cum.deaths
      }
      
    }
    data = rbind(data, tmp)
  }
  
  # Reorder data
  data <- with(data, data[order(date, age, cum.deaths, daily.deaths, code), ])
  data <- data[, c("date", "age", "cum.deaths", "daily.deaths", "code")]
  
}

obtain.TN.data = function(xlsx_file, Date){
  cat("\n Processing Tennessee \n")
  
  dates = seq.Date(as.Date("2020-03-22"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("tn", ".xlsx"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)
  
  xlsx_file = file.path(path_to_data, last.day, "tn.xlsx")
  
  tmp = suppressWarnings(subset(read_excel(xlsx_file), AGE_RANGE != "Pending") %>%
                           mutate(age = ifelse(AGE_RANGE == "0-10 years", "0-9",
                                               ifelse(AGE_RANGE == "81+ years", "80+", 
                                                      paste0(as.numeric(gsub("(.+)\\-.*", "\\1", AGE_RANGE))-1, "-",as.numeric(gsub(".*\\-(.+) years", "\\1", AGE_RANGE))-1) )),
                                  date = as.Date(DATE),
                                  code = "TN", 
                                  daily.deaths = NA_integer_) %>%
                           rename(cum.deaths = AR_TOTALDEATHS) %>%
                           select(age, date, code, cum.deaths, daily.deaths) )
  
  # keep first day without NA
  tmp = subset(tmp, !is.na(cum.deaths))
  
  dates = unique(tmp$date)
  print(sort(dates))
  
  for(t in 1:(length(dates)-1)){
    for(Age in unique(tmp$age)){
      Date = sort(dates)[-1][t]
      cum.death.t_1 = tmp[which(tmp$date == Date & tmp$age == Age),]$cum.deaths
      cum.death.t_0 = tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0 
      
      if((Date-1) %notin% dates){
        n.lost.days = as.numeric(Date - unique(tmp$date)[which(unique(tmp$date) == Date)-1])-1
        lost.days = Date - c(n.lost.days:1)
        
        cum.death.t_lag = tmp[which(tmp$date == Date & tmp$age == Age),]$cum.deaths
        cum.death.t_0 = tmp[which(tmp$date == (Date-n.lost.days-1) & tmp$age == Age ),]$cum.deaths
        daily.deaths = round((cum.death.t_lag - cum.death.t_0 )/(n.lost.days+1))
        
        stopifnot(is.numeric(daily.deaths))
        
        if( daily.deaths < 0 ) {
          daily.deaths = 0
          tmp[which(tmp$date == (Date-n.lost.days-1) & tmp$age == Age),]$daily.deaths = 
            max(0, tmp[which(tmp$date == (Date-n.lost.days-1)& tmp$age == Age),]$daily.deaths + daily.deaths)
        }
        # cum death are divided equally among the last two days
        tmp = dplyr::bind_rows(tmp, data.table(age = as.character(Age), 
                                                 date = as.Date(lost.days), 
                                                 cum.deaths = round(cum.death.t_0 + daily.deaths*c(1:n.lost.days)), 
                                                 daily.deaths = rep(daily.deaths, n.lost.days), code = "TN")) 
        
        tmp[which(tmp$date == Date & tmp$age == Age ),]$daily.deaths = daily.deaths
        tmp[which(tmp$date == Date & tmp$age == Age ),]$cum.deaths = daily.deaths + tmp[which(tmp$date == (Date-1) & tmp$age == Age ),]$cum.deaths
        
        
      } else{
        
        stopifnot(is.numeric(daily.deaths))
        if(daily.deaths<0){
          index = which(daily.deaths<0)
          tmp[which(tmp$date == (Date-1)& tmp$age == Age),]$daily.deaths[index] = sapply(tmp[which(tmp$date == (Date-1)& tmp$age == Age),]$daily.deaths[index] + daily.deaths[index], function(x) max(x,0))
          daily.deaths[index] = 0
          
        }
        tmp[which(tmp$date == Date & tmp$age == Age),]$daily.deaths = daily.deaths
        tmp[which(tmp$date == Date & tmp$age == Age),]$cum.deaths = daily.deaths + tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$cum.deaths
      }
    }
  }
  
  # Reorder data
  data.tn <- with(tmp, tmp[order(date, code, age, cum.deaths, daily.deaths), ])
  data.tn <- data.tn[, c("date", "code", "age", "cum.deaths", "daily.deaths")]
  
  return(as.data.table(data.tn))
}

obtain.CT.data = function(last.day){
  cat("\n Processing Connecticut \n")
  
  seq.Date(as.Date("2020-03-22"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("connecticut", ".csv"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)
  
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
    rename(cum.deaths = Total.deaths) %>%
    select(age, date, code, cum.deaths, daily.deaths)
  print(sort(unique(tmp$date)))
  for(t in 1:(length(unique(tmp$date))-1)){
    for(Age in unique(tmp$age)){
      Date = sort(unique(tmp$date))[-1][t]
      cum.death.t_1 = tmp[which(tmp$date == Date & tmp$age == Age),]$cum.deaths
      cum.death.t_0 = tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$cum.deaths
      daily.deaths = cum.death.t_1 - cum.death.t_0 
      stopifnot(is.numeric(daily.deaths))
      if(daily.deaths < 0){
        tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$daily.deaths =  max(tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$daily.deaths + daily.deaths, 0)
        daily.deaths = 0
        }
      tmp[which(tmp$date == Date & tmp$age == Age),]$daily.deaths = daily.deaths 
      tmp[which(tmp$age == Age & tmp$date == Date),]$cum.deaths = daily.deaths + tmp[which(tmp$age == Age & tmp$date == (Date-1)),]$cum.deaths
    }
  }
  
  # Reorder data
  data.ct <- with(tmp, tmp[order(date, code, age, cum.deaths, daily.deaths), ])
  data.ct <- data.ct[, c("date", "code", "age", "cum.deaths", "daily.deaths")]
  
return(data.ct)
}

obtain.CO.data = function(last.day){
  cat("\n Processing Colorado \n")
  
  dates=seq.Date(as.Date("2020-03-22"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("colorado", ".csv"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)

  csv_file = file.path(path_to_data, last.day, "colorado.csv")
  tmp = read.csv(csv_file)
  
  tmp$rep_date = as.Date(tmp$rep_date, format = "%m/%d/%y")
  
  tmp = tmp[grepl(", Deaths", tmp$attribute),] %>%
    mutate(age = gsub("(.+), Deaths", "\\1", attribute)) %>%
    rename(date = rep_date, cum.deaths = value) %>%
    select(age, date, cum.deaths) 
  
  tmp = tmp %>%
    mutate(age = factor(age, levels = c("0-9", as.character(unique(tmp$age))))) %>%
    complete(age, date, fill = list(cum.deaths= 0)) %>%
    mutate(daily.deaths = NA_integer_, 
           code = "CO",
           age = as.character(age))
  
  print(sort(unique(tmp$date)))

  for(t in 1:(length(unique(tmp$date))-1)){
    for(a in 1:length(unique(tmp$age))){
      Date = sort(unique(tmp$date))[-1][t]; Age = unique(tmp$age)[a]
      cum.deaths.t1 = tmp[which(tmp$date == Date & tmp$age == Age),]$cum.deaths
      cum.deaths.t0 = tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$cum.deaths
      daily.deaths = cum.deaths.t1 - cum.deaths.t0
      
      stopifnot(is.numeric(daily.deaths))
      if(daily.deaths < 0){
        tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$daily.deaths = max(tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$daily.deaths + daily.deaths, 0)
        daily.deaths = 0
      }
      tmp[which(tmp$date == Date & tmp$age == Age),]$daily.deaths = daily.deaths
      tmp[which(tmp$age == Age & tmp$date == Date),]$cum.deaths = daily.deaths + tmp[which(tmp$age == Age & tmp$date == (Date-1)),]$cum.deaths
    }
  }

  # remove unknown age
  tmp <- subset(tmp, age != "Unknown")
  # Reorder data
  data.co <- with(tmp, tmp[order(date, code, age, cum.deaths, daily.deaths), ])
  data.co <- data.co[, c("date", "code", "age", "cum.deaths", "daily.deaths")]

  return(data.co)
}

obtain.ME.data = function(last.day){
  cat("\n Processing Colorado \n")
  
  dates=seq.Date(as.Date("2020-03-22"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("maine", ".csv"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)
  
  csv_file = file.path(path_to_data, last.day, "maine.csv")
  
  tmp = as.data.table(read.csv(csv_file))
  tmp$Age.Ranges = rep(tmp$Age.Ranges[seq(1,nrow(tmp),2)], each = 2)
  levels(tmp$Age.Ranges) = list("0-19" = "<20", "20-29"="20s", "30-39" ="30s", "40-49"="40s",
       "50-59" = "50s", "60-69" = "60s", "70-79" = "70s", "80+" = "80+")
  tmp = tmp %>%
    subset(X == "Running Sum of Measure Toggle along LATEST_STATUS_DATE") %>%
    melt(id.vars = c("Age.Ranges", "X")) %>%
    mutate(value = ifelse(is.na(value), 0, value),
           date = as.Date(gsub("X(.+)", "\\1", variable), format = "%Y.%m.%d"),
           code = "ME",
           daily.deaths = NA_integer_) %>%
    rename(age = Age.Ranges,
           cum.deaths = value) %>%
    select(date, age, cum.deaths, daily.deaths, code)
  
  print(sort(tmp$date))
  
  for(t in 1:(length(unique(tmp$date))-1)){
    for(a in 1:length(unique(tmp$age))){
      Date = sort(unique(tmp$date))[-1][t]; Age = unique(tmp$age)[a]
      cum.deaths.t1 = tmp[which(tmp$date == Date & tmp$age == Age),]$cum.deaths
      cum.deaths.t0 = tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$cum.deaths
      daily.deaths = cum.deaths.t1 - cum.deaths.t0
      
      stopifnot(is.numeric(daily.deaths))
      if(daily.deaths < 0){
        tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$daily.deaths = max(tmp[which(tmp$date == (Date-1) & tmp$age == Age),]$daily.deaths + daily.deaths, 0)
        daily.deaths = 0
      }
      tmp[which(tmp$date == Date & tmp$age == Age),]$daily.deaths = daily.deaths
      tmp[which(tmp$age == Age & tmp$date == Date),]$cum.deaths = daily.deaths + tmp[which(tmp$age == Age & tmp$date == (Date-1)),]$cum.deaths
    }
  }

  # Reorder data
  data.me <- with(tmp, tmp[order(date, code, age, cum.deaths, daily.deaths), ])
  data.me <- data.me[, c("date", "code", "age", "cum.deaths", "daily.deaths")]
  
  return(data.me)
}

obtain.rulebased.data = function(last.day, state_name, state_code){
  
  # file with entire time series
  if(state_code %in% c("CO", "CT", "TN", "ME"))  data = do.call(paste0("obtain.", state_code, ".data"), list(last.day))

  # daily file
  if(state_code %notin% c("CO", "CT", "TN", "ME")) data = obtain.data.csv_and_xlsx(last.day, state_name, state_code)
  
  return(data)

}

## STATES WITH .JSON file
obtain.json.data = function(last.day, state_name, state_code){
  cat(paste0("\n Processing ", state_name,"\n"))
  
  dates = seq.Date(as.Date("2020-03-22"), last.day, by = "day")
  
  # check on which date there is indeed data (sometimes states do not update)
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0(state_name, ".json"), data_files)]
  if(state_name == "ma")  data_files_state = data_files_state[!grepl("oklahoma.json|alabama.json", data_files_state)] # we named massasschussets as ma ....
  
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  if(state_name == "alabama") dates = dates[which(dates >= as.Date("2020-05-03"))] # they changed age groups at this date
  first.day = dates[1]

  data = NULL
  
  for(t in 1:length(dates)){
    
    Date = dates[t]
    
    print(Date)

    json_file <- file.path(path_to_data, Date, paste0(state_name, ".json"))
    json_data <- suppressWarnings(fromJSON(paste(readLines(json_file))))
    
    # age groups changed for some states
    if(state_name == "NorthCarolina" & Date > as.Date("2020-05-19")){ 
      json_data_ = json_data[which(names(json_data) %in% c("0-17", "18-24", "25-49", "50-64"))]
      json_data_[["65+"]] = json_data[["65-74"]] + json_data[["75+"]]
      json_data = json_data_       
    }
    if(state_name == "arizona" & t > 2) names(json_data) = unique(data$age)
    if(state_name == "missouri" & Date > as.Date("2020-05-21")) names(json_data)[which(names(json_data) == "under 20")] = "Under 20"
    if(state_name == "pennsylvania" & Date > as.Date("2020-06-12")) names(json_data)[which(names(json_data) == "100+")] = ">100"
    if(state_name == "vermont" & Date > as.Date("2020-06-25")) names(json_data)[which(names(json_data) == "80+")] = "80 plus"
    if(state_name == "florida") names(json_data) = gsub("(.+) years", "\\1",names(json_data))
    
    # make sure that there is no space in the age group
    names(json_data) = gsub(" ", "", names(json_data), fixed = TRUE)
    
    tmp = data.table(age = names(json_data), cum.deaths = NA_integer_, daily.deaths = NA_integer_, 
                     code = state_code, date = Date)

    # remove unknown and total groups
    tmp = tmp[which(tmp$age != "Unknown"),]; tmp = tmp[which(tmp$age != "unknown"),]
    tmp = tmp[which(tmp$age != "total"),]; tmp = tmp[which(tmp$age != "Total"),]; tmp = tmp[which(tmp$age != "N"),]
    tmp = tmp[which(tmp$age != "Notavailable"),]; tmp = tmp[which(tmp$age != "Missing"),]
    
    for(age_group in tmp$age){
    
      if(state_name == "nyc"){
        cum.deaths = suppressWarnings(as.numeric(gsub("(.+) \\(.*", "\\1", json_data[[age_group]][1])))
        if(is.na(cum.deaths)) cum.deaths = as.numeric(gsub("(.+) \\(.*\\(.*", "\\1", json_data[[age_group]][1])) # sometimes mismatch 
        json_data[[age_group]] = cum.deaths
      }
      
      if(state_name == "washington"){
        cum.deaths = as.numeric(gsub("(.+)\\%", "\\1", json_data[[age_group]][1])) * as.numeric(gsub(",", "", json_data[["total"]])) / 100
        json_data[[age_group]] = cum.deaths
      }
      
      if(state_name == "new_jersey" & Date < as.Date("2020-06-22")){ # data changed from percentage to absolute value on this date
        cum.deaths = as.numeric(json_data[[age_group]][1]) * as.numeric(json_data[["N"]]) / 100
        json_data[[age_group]] = cum.deaths
      }
      
      if(any(grepl(",", json_data[[age_group]]))){
        index_comma = which(grepl(",", json_data[[age_group]]) == T)
        json_data[[age_group]][index_comma] = as.numeric(gsub(",", "", json_data[[age_group]][index_comma]))
      }
      
      # index inside the json varies states by state
      index = 1
      if(state_name == "ma") index = 2
      
      cum.deaths = as.integer(json_data[[age_group]][index])
      tmp[which(age == age_group),]$cum.deaths = cum.deaths
      
      if(Date > first.day){
        cum.death.t_1 = tmp[which(age == age_group & date == Date),]$cum.deaths
        cum.death.t_0 =  data[which(data$age == age_group & data$date == (Date-1)),]$cum.deaths
        daily.deaths = cum.death.t_1 - cum.death.t_0 
        
        if((Date - 1) %notin% dates){
          n.lost.days = as.numeric(Date - dates[which(dates == Date)-1] -1)
          lost.days = Date - c(n.lost.days:1)
          cum.death.t_lag = tmp[which(age == age_group & date == Date),]$cum.deaths
          cum.death.t_0 =  data[which(data$age == age_group & data$date == (Date-n.lost.days-1)),]$cum.deaths
          daily.deaths = round((cum.death.t_lag - cum.death.t_0 )/(n.lost.days+1))
          # cum death are divided equally among the last two days
          data = rbind(data, data.table(age = age_group, 
                                        date = lost.days, 
                                        cum.deaths = round(cum.death.t_0 + daily.deaths*c(1:n.lost.days)), 
                                        daily.deaths = rep(daily.deaths, n.lost.days), code = state_code))
        }
        
        stopifnot(is.numeric(daily.deaths) & !is.null(daily.deaths))
        
        if(daily.deaths<0){
          data[which(data$age == age_group & data$date == (Date-1)),]$daily.deaths = max(data[which(data$age == age_group & data$date == (Date-1)),]$daily.deaths + daily.deaths,0)
          daily.deaths = 0
        }
        tmp[which(age == age_group & date == Date),]$daily.deaths = daily.deaths
        tmp[which(age == age_group & date == Date),]$cum.deaths = daily.deaths + data[which(data$age == age_group & data$date == (Date-1)),]$cum.deaths
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
  
  if(state_name == "arizona" | state_name == "illinois"){
    data = data %>%
      mutate(age = ifelse(age == "<20", "0-19", age))
  }
  
  if(state_name == "louisiana"){
    data = suppressWarnings(data %>%
      mutate(age = ifelse(age == "<18", "0-19",
                          ifelse(age == "18-29", "20-29", age))))
      
  }
  
  if(state_name == "iowa"){
    data = data %>%
      mutate(age = ifelse(age == "18-40", "20-39", 
                          ifelse(age == "41-60", "40-59",
                                 ifelse(age == "61-80", "60-79",
                                        "80+"))))
  }
  
  if(state_name == "missouri"){
    data = data %>%
      mutate(age = ifelse(age == "Under20", "0-19", age))
  }
  
  if(state_name == "SouthCarolina"){
    data = suppressWarnings(data %>%
      mutate(age = ifelse(age == "81+", "80+", 
                          paste0(as.numeric(gsub("(.+)\\-.*", "\\1", age))-1, "-", as.numeric(gsub(".*\\-(.+)", "\\1", age))-1))))
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
  
  if(state_name == "new_jersey"){
    data = data %>%
      mutate(age = ifelse(age == "5-17", "5-19", 
                          ifelse(age == "18-29", "20-29",age)))
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
  
  # Reorder data
  data <- with(data, data[order(date, code, age, cum.deaths, daily.deaths), ])
  data <- data[, c("date", "code", "age", "cum.deaths", "daily.deaths")]
  
  return(data)
} 

`%notin%` = Negate(`%in%`)
