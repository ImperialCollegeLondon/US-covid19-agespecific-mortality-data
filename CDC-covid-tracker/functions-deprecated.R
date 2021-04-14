prepare_CDC_data = function(last.day,age_max,age.specification,indir){
  
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
    
    if(dates[t] == "2020-07-22") # fix bug in the data
      tmp[[t]][, End.Week := '07/18/2020']
    
    if(t > 1) 
      if(unique(tmp[[t]]$End.Week) == unique(tmp[[t-1]]$End.Week) )
      {
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
  
  #check which age specification (1 or 2) and censored the data accordingly
  if(age.specification == 1){
    tmp = subset(tmp, date < as.Date("2020-09-02"))
  } else {
    tmp = subset(tmp, date >= as.Date("2020-09-02"))
  }
  
  # boundaries if deaths is missing
  tmp[, min_COVID.19.Deaths := 1]
  tmp[, max_COVID.19.Deaths := 9]
  
  # rename age groups
  tmp[, Age.group := ifelse(Age.group == "Under 1 year", "0-0", 
                            ifelse(Age.group == "85 years and over", "85+", gsub("(.+) years", "\\1", Age.group)))]
  
  # group age groups
  if(age.specification == 1){
    tmp = group.age.specification.1(tmp)
  } else{
    tmp = group.age.specification.2(tmp)
  }
  
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

group.age.specification.1 = function(tmp)
{
  # group 0-0 and 1-4 age groups
  tmp1 = subset(tmp, Age.group %in% c('0-0', '1-4'))
  tmp1 = tmp1[, list(COVID.19.Deaths = sum(COVID.19.Deaths)), by = c('date', 'State', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths')]
  tmp1[, Age.group := '0-4']
  tmp = rbind(subset(tmp, !Age.group %in% c('0-0', '1-4')), tmp1)
  
  # add 5-9 age group
  tmp[Age.group == '5-14' & (is.na(COVID.19.Deaths) | COVID.19.Deaths > 0), min_COVID.19.Deaths := 0]
  tmp[Age.group == '5-14' & COVID.19.Deaths > 0, max_COVID.19.Deaths := COVID.19.Deaths]
  tmp[Age.group == '5-14' & (is.na(COVID.19.Deaths) | COVID.19.Deaths > 0), COVID.19.Deaths := NA]
  tmp[Age.group == '5-14', Age.group := '5-9'] # last option stays 0
  
  # add 10-17 age group
  tmp = add_missing_age_group_with_2_age_groups(tmp, '5-14', '15-24', '10-17')
  
  # add 18-29 age group
  tmp = add_missing_age_group_with_2_age_groups(tmp, '15-24', '25-34', '18-29')
  
  # add 30-49 age group
  tmp = add_missing_age_group_with_3_age_groups(tmp, '25-34', '35-44', '45-54', '30-49')
  
  # add 50-64 age group
  tmp = add_missing_age_group_with_2_age_groups(tmp, '45-54', '55-64', '50-64')
  
  
  # factor age
  tmp = subset(tmp, Age.group %in% c('0-4', '5-9', '10-17', '18-29', '30-49', '50-64', '65-74', '75-84', '85+'))
  # tmp[, Age.group := factor(Age.group, c('0-4', '5-14', '15-24', '25-44', '45-64', '65-74', '75-84', '85+'))]
  tmp[, Age.group := factor(Age.group, c('0-4', '5-9', '10-17', '18-29', '30-49', '50-64', '65-74', '75-84', '85+'))]
  
  # rm overall
  tmp = subset(tmp, !is.na(Age.group))
  
  # check that the number of age group is the same for every stata/date combinations
  tmp1 = tmp[, list(N = .N), by = c('State', 'date')]
  stopifnot(all(tmp1$N == 9))
  
  return(tmp)
}


group.age.specification.2 = function(tmp)
{
  
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
  
  return(tmp)
}

add_missing_age_group_with_2_age_groups = function(tmp, age_1, age_2, age_output){
  
  tmp_p = subset(tmp, Age.group == age_output)
  tmp = merge(tmp, unique(select(subset(tmp, Age.group != age_output), State, date )) )
  
  tmp1 = subset(tmp, Age.group == age_1)
  setnames(tmp1, 'COVID.19.Deaths', 'COVID.19.Deaths.age_1')
  tmp2 = subset(tmp, Age.group == age_2)
  setnames(tmp2, 'COVID.19.Deaths', 'COVID.19.Deaths.age_2')
  
  tmp1 = merge(tmp1, tmp2, by = c('date', 'State', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths'))
  
  tmp1[, COVID.19.Deaths := as.numeric(NA)]
  tmp1[, COVID.19.Deaths := as.numeric(COVID.19.Deaths)]
  tmp1[COVID.19.Deaths.age_1 == 0 & COVID.19.Deaths.age_2 == 0, COVID.19.Deaths := 0.0]
  tmp1[, min_COVID.19.Deaths := 0]
  tmp1[is.na(COVID.19.Deaths.age_1) & is.na(COVID.19.Deaths.age_2), max_COVID.19.Deaths := 2*max_COVID.19.Deaths]
  tmp1[is.na(COVID.19.Deaths.age_1) & COVID.19.Deaths.age_2 > 0, max_COVID.19.Deaths := COVID.19.Deaths.age_2 + max_COVID.19.Deaths]
  tmp1[COVID.19.Deaths.age_1 > 0 & is.na(COVID.19.Deaths.age_2), max_COVID.19.Deaths := COVID.19.Deaths.age_1 + max_COVID.19.Deaths]
  tmp1[COVID.19.Deaths.age_1 > 0 & COVID.19.Deaths.age_2 > 0, max_COVID.19.Deaths := COVID.19.Deaths.age_1 + COVID.19.Deaths.age_2]
  tmp1[, Age.group := age_output]
  tmp = rbind(tmp, select(tmp1, 'date', 'State', 'Age.group', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths', 'COVID.19.Deaths'))
  
  tmp = rbind(tmp, tmp_p)
  
  return(tmp)
}

add_missing_age_group_with_3_age_groups = function(tmp, age_1, age_2, age_3, age_output){
  
  tmp_p = subset(tmp, Age.group == age_output) 
  tmp = merge(tmp, unique(select(subset(tmp, Age.group != age_output), State, date )) )
  
  tmp1 = subset(tmp, Age.group == age_1)
  setnames(tmp1, 'COVID.19.Deaths', 'COVID.19.Deaths.age_1')
  tmp2 = subset(tmp, Age.group == age_2)
  setnames(tmp2, 'COVID.19.Deaths', 'COVID.19.Deaths.age_2')
  tmp1 = merge(tmp1, tmp2, by = c('date', 'State', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths'))
  
  tmp2 = subset(tmp, Age.group == age_3)
  setnames(tmp2, 'COVID.19.Deaths', 'COVID.19.Deaths.age_3')
  tmp1 = merge(tmp1, tmp2, by = c('date', 'State', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths'))
  
  
  tmp1[, COVID.19.Deaths := as.numeric(NA)]
  tmp1[, COVID.19.Deaths := as.numeric(COVID.19.Deaths)]
  tmp1[COVID.19.Deaths.age_1 == 0 & COVID.19.Deaths.age_2 == 0 & COVID.19.Deaths.age_3 == 0, COVID.19.Deaths := 0.0]
  tmp1[, min_COVID.19.Deaths := 0]
  
  tmp1[is.na(COVID.19.Deaths.age_1) & is.na(COVID.19.Deaths.age_2) & is.na(COVID.19.Deaths.age_3), max_COVID.19.Deaths := 3*max_COVID.19.Deaths]
  
  tmp1[is.na(COVID.19.Deaths.age_1) & is.na(COVID.19.Deaths.age_2) & COVID.19.Deaths.age_3 > 0, max_COVID.19.Deaths := COVID.19.Deaths.age_3 + 2*max_COVID.19.Deaths]
  tmp1[is.na(COVID.19.Deaths.age_1) & COVID.19.Deaths.age_2 > 0 & is.na(COVID.19.Deaths.age_3), max_COVID.19.Deaths := COVID.19.Deaths.age_2 + 2*max_COVID.19.Deaths]
  tmp1[COVID.19.Deaths.age_1 > 0 & is.na(COVID.19.Deaths.age_2) & is.na(COVID.19.Deaths.age_3), max_COVID.19.Deaths := COVID.19.Deaths.age_1 + 2*max_COVID.19.Deaths]
  
  tmp1[is.na(COVID.19.Deaths.age_1) & COVID.19.Deaths.age_2 > 0 & COVID.19.Deaths.age_3 > 0, max_COVID.19.Deaths := COVID.19.Deaths.age_2 + COVID.19.Deaths.age_3 + max_COVID.19.Deaths]
  tmp1[COVID.19.Deaths.age_1 > 0 & is.na(COVID.19.Deaths.age_2) & COVID.19.Deaths.age_3 > 0, max_COVID.19.Deaths := COVID.19.Deaths.age_1 + COVID.19.Deaths.age_3 + max_COVID.19.Deaths]
  tmp1[COVID.19.Deaths.age_1 > 0 & COVID.19.Deaths.age_2 > 0 & is.na(COVID.19.Deaths.age_3), max_COVID.19.Deaths := COVID.19.Deaths.age_1 + COVID.19.Deaths.age_2 + max_COVID.19.Deaths]
  
  tmp1[COVID.19.Deaths.age_1 > 0 & COVID.19.Deaths.age_2 > 0 & COVID.19.Deaths.age_3 > 0, max_COVID.19.Deaths := COVID.19.Deaths.age_1 + COVID.19.Deaths.age_2 + COVID.19.Deaths.age_3]
  
  tmp1[, Age.group := age_output]
  tmp = rbind(tmp, select(tmp1, 'date', 'State', 'Age.group', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths', 'COVID.19.Deaths'))
  
  tmp = rbind(tmp, tmp_p)
  
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


ensure_increasing_cumulative_deaths = function(tmp)
{
  
  dates = unique(tmp$date)
  
  for(t in 1:length(dates)){
    
    Date = rev(dates)[t]
    print(Date)
    #
    # check if cumulative death is strictly decreasing from last date to first date
    
    for(age_group in unique(tmp$age)){
      
      for(Code in unique(tmp$code)){
        
        if(Date < max(dates)){
          
          if(is.na(tmp[age == age_group & date == Date & code == Code, COVID.19.Deaths]))
            next
          if(is.na(tmp[age == age_group & date == rev(dates)[t-1] & code == Code, COVID.19.Deaths]))
            next
          
          # if cumulative date at date t < date t - 1, fix cum deaths at date t - 1 to the one at date t.
          if(tmp[age == age_group & date == Date & code == Code, COVID.19.Deaths] > tmp[age == age_group & date == rev(dates)[t-1] & code == Code, COVID.19.Deaths]){
            tmp[age == age_group & date == Date & code == Code,]$COVID.19.Deaths = tmp[age == age_group & date == rev(dates)[t-1] & code == Code, COVID.19.Deaths]
          }
          
        }
        
      }
    }
  }
  
  
  return(tmp)
}
