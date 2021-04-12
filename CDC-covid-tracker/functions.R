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
  idx.rm = c()
  for(t in 1:length(dates)){
    csv_file = file.path(path_to_data, dates[t], 'cdc.csv')
    tmp[[t]] = as.data.table( read.csv(csv_file) ) 
    if('End.Date' %in% names(tmp[[t]])) setnames(tmp[[t]], 'End.Date', 'End.Week')
    if('Age.Group' %in% names(tmp[[t]])) setnames(tmp[[t]], 'Age.Group', 'Age.group')
    
    if('Group'%in% names(tmp[[t]])) tmp[[t]] = subset(tmp[[t]], Group == 'By Total')
    
    stopifnot(length(unique(tmp[[t]]$End.Week)) == 1)
    
    if(t > 1) 
      if(unique(tmp[[t]]$End.Week) == unique(tmp[[t-1]]$End.Week) ){
        idx.rm = c(idx.rm, t)
        next
      }
    
    tmp[[t]] = select(tmp[[t]], State, 'End.Week', Sex, Age.group, COVID.19.Deaths)
  }
  tmp = do.call('rbind', tmp[-idx.rm])
  
  # set date variable
  tmp[, date := as.Date(End.Week, format = '%m/%d/%Y')]
  tmp = select(tmp, -End.Week)
  
  # sum over sex
  tmp = subset(tmp, Sex %in% c('Male', 'Female'))
  tmp = tmp[, list(COVID.19.Deaths = sum(COVID.19.Deaths)), by = c('date', 'State', 'Age.group')]
  
  # keep date only after "2020-09-02" to have all the age groups
  tmp = subset(tmp, date >= as.Date("2020-09-02"))
  
  # boundaries if deaths is missing
  tmp[, min_COVID.19.Deaths := 1]
  tmp[, max_COVID.19.Deaths := 9]
  
  # rename age groups
  tmp[, Age.group := ifelse(Age.group == "Under 1 year", "0-0", 
                            ifelse(Age.group == "85 years and over", "85+", gsub("(.+) years", "\\1", Age.group)))]
  
  # group 0-0 and 1-4 age groups
  tmp1 = subset(tmp, Age.group %in% c('0-0', '1-4'))
  tmp1 = tmp1[, list(COVID.19.Deaths = sum(COVID.19.Deaths)), by = c('date', 'State', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths')]
  tmp1[, Age.group := '0-4']
  tmp = rbind(subset(tmp, !Age.group %in% c('0-0', '1-4')), tmp1)
  
  # gather 30-39 and 40-49 
  tmp1 = subset(tmp, Age.group %in% c('30-39', '40-49'))
  tmp1 = tmp1[, list(COVID.19.Deaths = sum(COVID.19.Deaths)), by = c('date', 'State', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths')]
  tmp1[, Age.group := '30-49']
  tmp = rbind(subset(tmp, !Age.group %in% c('30-39', '40-49')), tmp1)
  
  # add 10-17 age group
  tmp[Age.group == '0-17' & (is.na(COVID.19.Deaths) | COVID.19.Deaths > 0), min_COVID.19.Deaths := 0]
  tmp[Age.group == '0-17' & COVID.19.Deaths > 0, max_COVID.19.Deaths := COVID.19.Deaths]
  tmp[Age.group == '0-17' & (is.na(COVID.19.Deaths) | COVID.19.Deaths > 0), COVID.19.Deaths := NA]
  tmp[Age.group == '0-17', Age.group := '10-17']
  
  # add 5-9 age group
  tmp[Age.group == '5-14' & (is.na(COVID.19.Deaths) | COVID.19.Deaths > 0), min_COVID.19.Deaths := 0]
  tmp[Age.group == '5-14' & COVID.19.Deaths > 0, max_COVID.19.Deaths := COVID.19.Deaths]
  tmp[Age.group == '5-14' & (is.na(COVID.19.Deaths) | COVID.19.Deaths > 0), COVID.19.Deaths := NA]
  tmp[Age.group == '5-14', Age.group := '5-9']
  
  # factor age
  tmp = subset(tmp, !Age.group %in% c("0-17", '5-14', '15-24', '25-34', '35-44', '45-54','55-64', "All Ages", "All ages"))
  tmp[, Age.group := factor(Age.group, c('0-4', '5-9', '10-17', '18-29', '30-49', '50-64', '65-74', '75-84', '85+'))]
  
  # rm overall
  tmp = subset(tmp, !is.na(Age.group))
  
  # check that the number of age group is the same for every stata/date combinations
  tmp1 = tmp[, list(N = .N), by = c('State', 'date')]
  stopifnot(all(tmp1$N == 9))
  
  # rm US and add code
  setnames(tmp, c('Age.group', 'State'), c("age", "loc_label"))
  tmp = subset(tmp, loc_label != 'United States')
  tmp = merge(tmp, map_statename_code, by.x = 'loc_label', by.y = 'State')
  
  # find age from and age to
  tmp[, age_from := as.numeric(ifelse(grepl("\\+", age), gsub("(.+)\\+", "\\1", age), gsub("(.+)-.*", "\\1", age)))]
  tmp[, age_to := as.numeric(ifelse(grepl("\\+", age), age_max, gsub(".*-(.+)", "\\1", age)))]
  
  # order
  tmp = tmp[order(loc_label, date, age)]
  
  # ensure that it is cumulative
  tmp1 = tmp[, list(noncum = na.omit(COVID.19.Deaths) <= cummax(na.omit(COVID.19.Deaths))), by = c('loc_label', 'date', 'age')]
  stopifnot(all(tmp1$noncum))
  
  # plot
  if(0){
    ggplot(tmp, aes(x = date, y = COVID.19.Deaths, col = age)) + 
      geom_line() + 
      facet_grid(loc_label~.,  scales = 'free') + 
      theme_bw()
  }
  
  return(tmp)
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
