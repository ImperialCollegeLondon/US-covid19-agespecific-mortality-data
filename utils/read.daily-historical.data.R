read.TX.file = function(xlsx_file, Date){

  tmp = read_excel(xlsx_file, sheet = "Fatalities by Age Group", col_names = c("age", "cum.deaths", "perc"))
  # they changed the format of their table on the 07/27
  tmp = tmp[tmp$age %in% c("<1 year", "1-9 years", "10-19 years", "20-29 years", "30-39 years", "40-49 years", "50-59 years", "60-64 years",
                       "65-69 years", "70-74 years", "75-79 years","80+ years"),c("age","cum.deaths")]
  
  tmp = tmp %>%
    mutate(age = ifelse(age == "<1 year", "0-1", gsub("(.+) years", "\\1", age)), # group 0-1 and 2-9 for analysis
           code = "TX", 
           date = Date,
           cum.deaths = as.numeric(cum.deaths), 
           daily.deaths = NA_integer_) %>%
    select(age, code, date, daily.deaths, cum.deaths) 
  
  return(tmp)
}

read.GA.file = function(csv_file, Date){
  
  tmp = read.csv(csv_file)
  tmp = subset(tmp, !is.na(age) & age != ".")
  agedf = data.table(age = 0:109, age_break = cut(0:109, breaks = seq(0, 110, 5), include.highest = FALSE, right = FALSE))
  agedf[, age_cat :=  ifelse(age_break %in% c("[90,95)", "[95,100)", "[100,105)", "[105,110)"), "90+",
                             paste0(as.numeric(gsub("\\[(.+),.*", "\\1", age_break)), "-", as.numeric( sub("[^,]*,([^]]*)\\)", "\\1", age_break))-1))]
  
  agedf[, age_cat := as.factor(age_cat)]

  if(Date >= as.Date("2020-05-12")){ # age groups change on this date
    tmp$age = as.character(tmp$age)
    tmp[which(tmp$age == "90+"),]$age = "90"
    tmp$age = as.numeric(tmp$age)
  }
  
  tmp = as.data.table(tmp) %>%
    merge(agedf, by = "age") %>%
    group_by(age_cat) %>%
    summarise(cum.deaths = n()) %>%
    complete(age_cat, fill = list(cum.deaths= 0)) %>%
    mutate(age = age_cat,
           date = Date,
           code = "GA",
           daily.deaths = NA_integer_) %>%
    select(age, cum.deaths, daily.deaths, code, date)
  tmp[is.na(tmp$cum.deaths),]$cum.deaths = 0
  
  return(tmp)
}

read.ID.file = function(csv_file, Date){
  
  tmp = read.csv(csv_file) %>%
    mutate(age = ifelse(Age.Group.Ten == "<18", "0-17", 
                        ifelse(Age.Group.Ten == "18-29 years", "18-29", 
                               ifelse(Age.Group.Ten == "80", "80+", as.character(Age.Group.Ten)))), # group 0-1 and 2-9 for analysis
           code = "ID", 
           date = Date,
           cum.deaths = as.numeric(Deaths), 
           daily.deaths = NA_integer_) %>%
    select(age, code, date, daily.deaths, cum.deaths) 
  
  return(tmp)  
}

read.AK.file = function(csv_file, Date){
  
  tmp = subset(read.csv(csv_file), grepl("Years", Demographic)) %>%
    mutate(age = gsub("(.+) Years", "\\1", ifelse(Demographic == "<10 Years", "0-9 Years", as.character(Demographic))),
           code = "AK", 
           date = Date,
           is_after_0622 = date > as.Date("2020-06-22"),
           is_before_0826 = date < as.Date("2020-08-26"),
           cum.deaths = ifelse(is_after_0622 & is_before_0826, as.numeric(Deceased_Cases), as.numeric(Deaths)), # name of death variable changed on this date
           daily.deaths = NA_integer_) %>%
    select(age, code, date, daily.deaths, cum.deaths) 
  
  return(tmp)
  
}

read.RI.file = function(csv_file, Date){
  
  tmp = read.csv(csv_file)
  colnames(tmp)[1] = "age"
  rows_age = grepl("\\d\\-\\d|\\d\\+",tmp[,1])
  tmp = as.data.table(suppressWarnings(tmp[rows_age,] %>%
                                         mutate(code = "RI", 
                                                date = Date,
                                                cum.deaths = ifelse(grepl("<", Deaths), 0, as.numeric(as.character(Deaths))), 
                                                daily.deaths = NA_integer_) %>%
                                         select(age, code, date, daily.deaths, cum.deaths) ))
  
  # group 90-99 and 100 before 2020-09-03 because removed after
  if(Date < as.Date("2020-09-03")){
    tmp1 = tmp[age %in% c("90-99", "100+"), list(cum.deaths = sum(cum.deaths), code = code, date = date, daily.deaths = daily.deaths, age = "90+")]
    tmp = rbind(tmp[! age%in% c("90-99", "100+")], tmp1[1,])
    tmp[age == "10-19", age := "10-18"]
    tmp[age == "20-29", age := "19-29"]
  }
  
  # group 0-4 and 5-9, 10-14 and 15-18, 19-24 and 25-29
  if(Date >= as.Date("2020-09-03")){
    tmp1 = tmp[age %in% c("0-4", "5-9"), list(cum.deaths = sum(cum.deaths), code = code, date = date, daily.deaths = daily.deaths, age = "0-9")]
    tmp2 = tmp[age %in% c("10-14", "15-18"), list(cum.deaths = sum(cum.deaths), code = code, date = date, daily.deaths = daily.deaths, age = "10-18")]
    tmp3 = tmp[age %in% c("19-24", "25-29"), list(cum.deaths = sum(cum.deaths), code = code, date = date, daily.deaths = daily.deaths, age = "19-29")]
    tmp = rbind(rbind(rbind(tmp[! age%in% c("0-4", "5-9", "10-14", "15-18", "19-24", "25-29")], tmp1[1,]), tmp2[1,], tmp3[1,]))
  }
  
  return(tmp)
}

read.TN.file = function(last.day){
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("tn.xlsx"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)
  
  xlsx_file = file.path(path_to_data, last.day, "tn.xlsx")
  
  tmp = suppressWarnings(subset(read_excel(xlsx_file), AGE_RANGE != "Pending") %>%
                           mutate(age = ifelse(AGE_RANGE == "81+ years", "81+", 
                                                      paste0(as.numeric(gsub("(.+)\\-.*", "\\1", AGE_RANGE)), "-",
                                                             as.numeric(gsub(".*\\-(.+) years", "\\1", AGE_RANGE)))),
                                  date = as.Date(DATE),
                                  code = "TN", 
                                  daily.deaths = NA_integer_) %>%
                           rename(cum.deaths = AR_TOTALDEATHS) %>%
                           select(age, date, code, cum.deaths, daily.deaths) )
  
  # keep first day without NA
  tmp = subset(tmp, !is.na(cum.deaths))
  
  return(tmp)
}

read.CT.file = function(last.day){
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("connecticut.csv"), data_files)]
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
  
  return(tmp)
}

read.CO.file = function(last.day){
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("colorado.csv"), data_files)]
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
  
  tmp = subset(tmp, age != "Unknown")
  
  return(tmp)
}

read.ME.file = function(last.day){
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("maine.csv"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)
  
  csv_file = file.path(path_to_data, last.day, "maine.csv")
  
  tmp = as.data.table(read.csv(csv_file))
  tmp$Age.Ranges = rep(tmp$Age.Ranges[seq(1,nrow(tmp),2)], each = 2)
  
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
  
  tmp$age = as.factor(tmp$age)
  levels(tmp$age) = list("0-19" = "<20", "20-29"="20s", "30-39" ="30s", "40-49"="40s",
                         "50-59" = "50s", "60-69" = "60s", "70-79" = "70s", "80+" = "80+")
  return(tmp)
}

read.WI.file = function(last.day){
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("wisconsin.csv"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)
  
  csv_file = file.path(path_to_data, last.day, "wisconsin.csv")
  
  tmp = reshape2::melt (as.data.table(read.csv(csv_file)) , id.vars = "Date") %>%
    subset(variable != "X") %>%
    rename(cum.deaths = value) %>%
    mutate(date = as.Date(Date),
           code = "WI",
           daily.deaths = NA_integer_,
           age = factor(as.character(variable))) %>%
    select(date, age, code, cum.deaths, daily.deaths)
  levels(tmp$age) = list("0-9" = "X0.9.years", "10-19" = "X10.19.years", "20-29"="X20.29.years",
                         "30-39" ="X30.39.years", "40-49"="X40.49.years", "50-59" = "X50.59.years", 
                         "60-69" = "X60.69.years", "70-79" = "X70.79.years", "80-89" = "X80.89.years",
                         "90+" = "X90..years")
  return(tmp)
}

read.NM.file = function(last.day){
  
  cat("\n Processing ", "New Mexico", " \n")
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("new_mexico.csv"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)
  
  csv_file = file.path(path_to_data, last.day, "new_mexico.csv")
  
  tmp = reshape2::melt (as.data.table(read.csv(csv_file)) , id.vars = "Date") %>%
    subset(variable != "Total" & Date != "") %>%
    rename(daily.deaths = value) %>%
    mutate(date = as.Date(Date, format = "%d/%m/%y"),
           code = "NM",
           age = factor(as.character(variable))) %>%
    select(date, age, code, daily.deaths) %>%
    group_by(age) %>%
    mutate(cum.deaths = cumsum(daily.deaths)) %>%
    ungroup()
  levels(tmp$age) = list("0-19" = "X0.19.years", "20-29"="X20.29.years", "30-39" ="X30.39.years", 
                         "40-49"="X40.49.years", "50-59" = "X50.59.years", "60-69" = "X60.69.years", 
                         "70-79" = "X70.79.years", "80+" = "X80..years")
  
  stopifnot(all(tmp$daily.deaths >= 0 )) # TODO need to write a fix if this is not the case.
  data <- with(tmp, tmp[order(date, code, age, cum.deaths, daily.deaths), ])
  data <- data[, c("date", "code", "age", "cum.deaths", "daily.deaths")]
  
  print(unique(tmp$date))
  
  return(data)
}

read.VA.file = function(last.day){
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0("virginia.csv"), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  last.day = max(dates)
  
  csv_file = file.path(path_to_data, last.day, "virginia.csv")
  tmp = read.csv(csv_file)
  
  tmp = read.csv(csv_file) %>%
    mutate(date = as.Date(Report.Date, format = "%m/%d/%Y")) %>%
    rename(cum.deaths = Number.of.Deaths, age = Age.Group) %>%
    subset(!is.na(cum.deaths) & Health.District != "" & age != "Missing") %>%
    group_by(date, age) %>%
    summarise(cum.deaths = sum(cum.deaths)) %>%
    mutate(daily.deaths = NA_integer_, 
           code = "VA") %>%
    select(age, date, cum.deaths, daily.deaths, code) 

  return(tmp)
}