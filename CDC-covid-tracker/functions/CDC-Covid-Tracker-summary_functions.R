prepare_CDC_data = function(last.day,age_max,indir){
  
  path_to_data = file.path(indir, 'data')
  
  state_name = 'cdc'
  state_code = 'CDC'
  
  dates = seq.Date(as.Date("2020-03-01"), last.day, by = "day")
  
  file_format = ".csv"
  
  # find dates with data
  data_files = list.files(file.path(path_to_data, dates), full.names = T)
  data_files_state = data_files[grepl(paste0(state_name, file_format), data_files)]
  dates = as.Date(gsub( ".*\\/(.+)\\/.*", "\\1", data_files_state))
  
  tmp = vector(mode = 'list', length = length(dates))
  for(t in 1:length(dates)){
    csv_file = file.path(path_to_data, dates[t], 'cdc.csv')
    tmp[[t]] = as.data.table( read.csv(csv_file) ) 
    if('Data.As.Of' %in% names(tmp[[t]])) setnames(tmp[[t]], 'Data.As.Of', 'Data.as.of')
    if('Age.Group' %in% names(tmp[[t]])) setnames(tmp[[t]], 'Age.Group', 'Age.group')
    tmp[[t]] = select(tmp[[t]], State, 'Data.as.of', Sex, Age.group, COVID.19.Deaths)
  }
  tmp = do.call('rbind', tmp)
  
  tmp = subset(tmp, Sex %in% c('Male', 'Female'))
  
  # sum over sex
  tmp = tmp[, list(COVID.19.Deaths = sum(COVID.19.Deaths)), by = c('Data.as.of', 'State', 'Age.group')]
  
  # organise age groups
  tmp[, Age.group := ifelse(Age.group == "Under 1 year", "0-0", 
                            ifelse(Age.group == "85 years and over", "85+", gsub("(.+) years", "\\1", Age.group)))]
  tmp = subset(tmp, !Age.group %in% c("0-17", '18-29', "30-49", "50-64", "All Ages", "All ages"))
  tmp[, Age.group := factor(Age.group, c('0-0', '1-4', '5-14', '15-24', '25-34', '35-44', '45-54', '55-64', '65-74', '75-84', '85+'))]
  
  # set date variable
  tmp[, date := as.Date(Data.as.of, format = '%m/%d/%Y')]
  tmp = select(tmp, -Data.as.of)
  
  # rm overall
  tmp = subset(tmp, !is.na(Age.group))
  
  # check that the number of age group is the same for every stata/date combinations
  tmp1 = tmp[, list(N = .N), by = c('State', 'date')]
  stopifnot(all(tmp1$N == 11))
  
  # rm US and add code
  setnames(tmp, c('Age.group', 'State'), c("age", "loc_label"))
  tmp = subset(tmp, loc_label != 'United States')
  tmp = merge(tmp, map_statename_code, by.x = 'loc_label', by.y = 'State')
  
  # find age from and age to
  tmp[, age_from := as.numeric(ifelse(grepl("\\+", age), gsub("(.+)\\+", "\\1", age), gsub("(.+)-.*", "\\1", age)))]
  tmp[, age_to := as.numeric(ifelse(grepl("\\+", age), age_max, gsub(".*-(.+)", "\\1", age)))]
  
  
  return(tmp)
}

create_map_age = function(age_max){
  # create map by 5-year age bands
  df_age_continuous <<- data.table(age_from = 0:age_max,
                                   age_to = 0:age_max,
                                   age_index = 0:age_max,
                                   age = c(0.1, 1:age_max))
  
  # create map for reporting age groups
  df_age_reporting <<- data.table(age_from = c(0,1,5,15,25,35,45,55,65,75,85),
                                  age_to = c(0,4,14,24,34,44,54,64,74,84,age_max),
                                  age_index = 1:11,
                                  age_cat = c('0-0', '1-4', '5-14', '15-24', '25-34', '35-44', '45-54', '55-64', '65-74', '75-84', '85+'))
  df_age_reporting[, age_from_index := which(df_age_continuous$age_from == age_from), by = "age_cat"]
  df_age_reporting[, age_to_index := which(df_age_continuous$age_to == age_to), by = "age_cat"]
  
  # create map for 4 new age groups
  df_ntl_age_strata <<- data.table(age_cat = c("0-24", "25-49", "50-74", "75+"),
                                   age_from = c(0, 25, 50, 75),
                                   age_to = c(24, 49, 74, age_max),
                                   age_index = 1:4)
  df_ntl_age_strata[, age_from_index := which(df_age_continuous$age_from == age_from), by = "age_cat"]
  df_ntl_age_strata[, age_to_index := which(df_age_continuous$age_to == age_to), by = "age_cat"]
}

prepare_stan_data = function(deathByAge, JHUData, loc_name){
  
  tmp = subset(deathByAge, loc_label == loc_name)
  tmp = tmp[order(date, age_from)]
  Code <<- unique(tmp$code)
  stopifnot(all(tmp$age_from <= tmp$age_to))
  
  # create map of original age groups 
  df_state_age_strata <<- unique(select(tmp, age_from, age_to, age))
  df_state_age_strata[, age_index := 1:nrow(df_state_age_strata)]
  df_state_age_strata[, age_from_index := which(df_age_continuous$age_from == age_from), by = "age"]
  df_state_age_strata[, age_to_index := which(df_age_continuous$age_to == age_to), by = "age"]
  
  # number of age groups 
  B = nrow(df_state_age_strata)
  
  # select number of weeks: at least one positive deaths
  tmp1 = tmp[, list(n_deaths = sum(na.omit(COVID.19.Deaths))), by = 'date']
  dates = subset(tmp1, n_deaths >0)$date
  tmp = subset(tmp, date %in% dates)
  tmp <<- tmp
  
  # map week index
  W = length(unique(tmp$date))
  df_week <<- data.table(week_index = 1:W, date = unique(tmp$date))
  
  # create map of original age groups without NA 
  N_idx_non_missing = vector(mode = 'integer', length = W)
  N_idx_missing = vector(mode = 'integer', length = W)
  idx_non_missing = matrix(nrow = B, ncol = W, 0)
  idx_missing = matrix(nrow = B, ncol = W, 0)
  deaths = matrix(nrow = B, ncol = W, 0)
  
  for(w in 1:W){
    Week = sort(unique(tmp$date))[w]
    
    tmp1 = subset(tmp, date == Week & !is.na( COVID.19.Deaths ))
    df_state_age_strata_non_missing = unique(select(tmp1, age_from, age_to, age))
    
    # number of non missing and missing age category 
    N_idx_non_missing[w] = nrow(df_state_age_strata_non_missing)
    N_idx_missing[w] = B - N_idx_non_missing[w]
    
    # index missing and non missing
    .idx_non_missing = which(df_state_age_strata$age %in% df_state_age_strata_non_missing$age)
    .idx_missing = which(!df_state_age_strata$age %in% df_state_age_strata_non_missing$age)
    idx_non_missing[,w] = c(.idx_non_missing, rep(-1, B - length(.idx_non_missing)))
    idx_missing[,w] = c(.idx_missing, rep(-1, B - length(.idx_missing)))
    
    # deaths
    tmp1 = copy(tmp)
    tmp1[is.na(COVID.19.Deaths), COVID.19.Deaths := -1]
    deaths = reshape2::dcast(tmp1, age ~ date, value.var = 'COVID.19.Deaths')[,-1]
  }
  
  # create stan data list
  stan_data <- list()
  
  # age bands
  stan_data = c(stan_data, 
                list(W = W,
                     A = nrow(df_age_continuous),
                     age = df_age_continuous$age,
                     age2 = (df_age_continuous$age)^2,
                     B = B, 
                     age_from_state_age_strata = df_state_age_strata$age_from_index,
                     age_to_state_age_strata = df_state_age_strata$age_to_index,
                     N_idx_non_missing = N_idx_non_missing,
                     N_idx_missing = N_idx_missing,
                     idx_non_missing = idx_non_missing,
                     idx_missing = idx_missing,
                     deaths = deaths
                ))
  
  stan_data$age = stan_data$age / sd(stan_data$age)
  stan_data$age2 = stan_data$age2 / sd(stan_data$age2)
  
  # range of the censored data
  stan_data$range_censored = c(1,9)
  
  
  return(stan_data)
}


map_statename_code = data.table(State = c(
  "Alabama"         ,         
  "Alaska"          ,         
  "Arizona"	        ,         
  "Arkansas"        ,         
  "California"      ,         
  "Colorado"        ,         
  "Connecticut"     ,         
  "Delaware"        ,         
  "Florida"         ,         
  "Georgia"         ,         
  "Hawaii"          ,         
  "Idaho"           ,         
  "Illinois"        ,         
  "Indiana"         ,         
  "Iowa"            ,         
  "Kansas"          ,         
  "Kentucky"        ,         
  "Louisiana"	      ,         
  "Maine"           ,         
  "Maryland"        ,         
  "Massachusetts"   ,         
  "Michigan"        ,         
  "Minnesota"       ,         
  "Mississippi"     ,         
  "Missouri"        ,         
  "Montana"         ,         
  "Nebraska"        ,         
  "Nevada"          ,         
  "New Hampshire"   ,         
  "New Jersey"      ,         
  "New Mexico"      ,         
  "New York"        ,         
  "North Carolina"  ,         
  "North Dakota"    ,         
  "Ohio"            ,         
  "Oklahoma"        ,         
  "Oregon"	        ,         
  "Pennsylvania"    ,         
  "Rhode Island"    ,         
  "South Carolina"  ,         
  "South Dakota"    ,         
  "Tennessee"	      ,         
  "Texas"	          ,         
  "Utah"	          ,         
  "Vermont"         ,         
  "Virginia"        ,         
  "Washington"      ,         
  "West Virginia"   ,         
  "Wisconsin",	               
  "Wyoming"), 
  code = c(
    "AL",
    "AK",
    "AZ",
    "AR",
    "CA",
    "CO",
    "CT",
    "DE",
    "FL",
    "GA",
    "HI",
    "ID",
    "IL",
    "IN",
    "IA",
    "KS",
    "KY",
    "LA",
    "ME",
    "MD",
    "MA",
    "MI",
    "MN",
    "MS",
    "MO",
    "MT",
    "NE",
    "NV",
    "NH",
    "NJ",
    "NM",
    "NY",
    "NC",
    "ND",
    "OH",
    "OK",
    "OR",
    "PA",
    "RI",
    "SC",
    "SD",
    "TN",
    "TX",
    "UT",
    "VT",
    "VA",
    "WA",
    "WV",
    "WI",
    "WY"))

