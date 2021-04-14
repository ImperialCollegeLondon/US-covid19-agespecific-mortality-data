prepare_CDC_data = function(last.day,age_max,age.specification,sex,indir, check_increasing_cumulative_deaths =0)
  {
  
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
    
    if(dates[t] == "2020-07-08") # repeat previous data
    {
      idx.rm = c(idx.rm, t)
      next
    }
    
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
  
  #check which age specification (1 or 2) and censored the data accordingly
  if(age.specification == 1){
    tmp = subset(tmp, date < as.Date("2020-09-02"))
  } else {
    tmp = subset(tmp, date >= as.Date("2020-09-02"))
  }
  
  # boundaries if deaths is missing
  tmp[, min_COVID.19.Deaths := 1]
  tmp[, max_COVID.19.Deaths := 9]
  
  # choose sex
  tmp = subset(tmp, Sex == sex)
  
  # bugfix if there is a 0 before and after NA
  tmp = fix_inconsistent_NA_between0(tmp)
  tmp = fix_inconsistent_NA_betweenpos(tmp)
  
  # ensure increasing cumulative deaths
  if(check_increasing_cumulative_deaths){ # costly computationally, run when new data
    tmp = ensure_increasing_cumulative_deaths_origin(tmp)
  } else{ # bugfix already noticed
    tmp = bugfix_nonincreasing_cumulative_deaths(tmp)
  }
  
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
  tmp = sum_over_2_age_groups(tmp, '0-0', '1-4', '0-4')
  
  # factor age
  tmp = subset(tmp, !Age.group %in% c("0-17", '18-29', '30-49', '50-64', "All Ages", "All ages"))
  # tmp[, Age.group := factor(Age.group, c('0-4', '5-14', '15-24', '25-44', '45-64', '65-74', '75-84', '85+'))]
  tmp[, Age.group := factor(Age.group, c('0-4', '5-14', '15-24', '25-34', '35-44', '45-54', '55-64', '65-74', '75-84', '85+'))]
  
  # rm overall
  tmp = subset(tmp, !is.na(Age.group))
  
  # check that the number of age group is the same for every stata/date combinations
  tmp1 = tmp[, list(N = .N), by = c('State', 'date')]
  stopifnot(all(tmp1$N == 10))
  
  # sanity checks
  tmp1 = tmp[, list(idx_last_NA = which(is.na(COVID.19.Deaths))), by = c("State", 'Age.group')]
  tmp2 = tmp1[, list(min_idx_last_NA = min(idx_last_NA), max_idx_last_NA = max(idx_last_NA)), by = c("State", 'Age.group')]
  tmp1 = merge(tmp1, tmp2, by = c("State", 'Age.group'))
  tmp1 = tmp1[, list(all.inside = all( c(unique(min_idx_last_NA):unique(max_idx_last_NA)) %in% idx_last_NA )), by = c("State", 'Age.group')]
  stopifnot(all(tmp1$all.inside == T))
  
  return(tmp)
}

group.age.specification.2 = function(tmp)
{
  # group 0-0 and 1-4 age groups
  tmp = sum_over_2_age_groups(tmp, '0-0', '1-4', '0-4')
  
  # gather 30-39 and 40-49
  tmp = sum_over_2_age_groups(tmp, '30-39', '40-49', '30-49')
  
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
  tmp = subset(tmp, Age.group %in% c('0-4', '5-9', '10-17', '18-29', '30-49', '50-64', '65-74', '75-84', '85+'))
  tmp[, Age.group := factor(Age.group, c('0-4', '5-9', '10-17', '18-29', '30-49', '50-64', '65-74', '75-84', '85+'))]
  
  # rm overall
  tmp = subset(tmp, !is.na(Age.group))
  
  # check that the number of age group is the same for every state/date combinations
  tmp1 = tmp[, list(N = .N), by = c('State', 'date')]
  stopifnot(all(tmp1$N == 9))
  
  # check the boundaries
  stopifnot(tmp$max_COVID.19.Deaths > tmp$min_COVID.19.Deaths)
  
  return(tmp)
}

fix_inconsistent_NA_between0 = function(tmp)
  {

  tmp1 = tmp[, list(idx_last_0 = (which(COVID.19.Deaths == 0))), by = c("State", 'Age.group')]
  tmp1 = tmp1[, list(idx_last_0 = max(idx_last_0)), by = c("State", 'Age.group')]
  
  tmp2 = unique(select(tmp, "State", 'Age.group'))
  tmp1 = merge(tmp1, tmp2, by = c("State", 'Age.group'), all.y = T)
  
  tmp = merge(tmp, tmp1, by = c("State", 'Age.group'))
  tmp[, date_idx := 1:length(date), by = c("State", 'Age.group')]
  tmp[date_idx <= idx_last_0 & is.na(COVID.19.Deaths), COVID.19.Deaths := 0]
  
  tmp = select(tmp, -date_idx, -idx_last_0)
  
  return(tmp)
}

fix_inconsistent_NA_betweenpos = function(tmp)
  {
  
  tmp1 = tmp[, list(idx_NA = (which(is.na(COVID.19.Deaths)))), by = c("State", 'Age.group')]
  tmp1 = tmp1[, list(idx_last_NA = max(idx_NA), idx_first_NA = min(idx_NA)), by = c("State", 'Age.group')]
  
  tmp2 = unique(select(tmp, "State", 'Age.group'))
  tmp1 = merge(tmp1, tmp2, by = c("State", 'Age.group'), all.y = T)
  
  tmp = merge(tmp, tmp1, by = c("State", 'Age.group'))
  tmp[, date_idx := 1:length(date), by = c("State", 'Age.group')]
  tmp[date_idx >= idx_first_NA & date_idx <= idx_last_NA & COVID.19.Deaths > 0 & COVID.19.Deaths < 15, COVID.19.Deaths := NA]
  
  stopifnot(unique(tmp[date_idx == (idx_first_NA - 1)]$COVID.19.Deaths)==0)
  
  tmp = select(tmp, -date_idx, -idx_first_NA, -idx_last_NA)
  
  return(tmp)
}

sum_over_2_age_groups = function(tmp, age_1, age_2, age_output)
  {
  
  tmp_p = select(subset(tmp, Age.group == age_output), State, date)
  tmp_p = merge(tmp, tmp_p, by = c('State', 'date'))
  tmp = anti_join(tmp, tmp_p, by = c('State', 'date'))
  
  tmp1 = subset(tmp, Age.group == age_1)
  setnames(tmp1, c('COVID.19.Deaths', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths'), 
           c('COVID.19.Deaths.age_1', 'min_COVID.19.Deaths.age_1', 'max_COVID.19.Deaths.age_1'))
  tmp2 = subset(tmp, Age.group == age_2)
  setnames(tmp2, c('COVID.19.Deaths', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths'), 
           c('COVID.19.Deaths.age_2', 'min_COVID.19.Deaths.age_2', 'max_COVID.19.Deaths.age_2'))
  
  tmp1 = merge(tmp1, tmp2, by = c('date', 'State', 'Sex'))
  
  tmp1[, COVID.19.Deaths := as.numeric(NA)]
  tmp1[, COVID.19.Deaths := as.numeric(COVID.19.Deaths)]
  tmp1[, min_COVID.19.Deaths := 1]
  tmp1[, min_COVID.19.Deaths := as.numeric(min_COVID.19.Deaths)]
  tmp1[, max_COVID.19.Deaths := 9]
  tmp1[, max_COVID.19.Deaths := as.numeric(max_COVID.19.Deaths)]
  
  tmp1[COVID.19.Deaths.age_1 == 0 & COVID.19.Deaths.age_2 == 0, COVID.19.Deaths := 0.0]

  tmp1[is.na(COVID.19.Deaths.age_1) & is.na(COVID.19.Deaths.age_2), max_COVID.19.Deaths := max_COVID.19.Deaths.age_1+max_COVID.19.Deaths.age_2]
  tmp1[is.na(COVID.19.Deaths.age_1) & is.na(COVID.19.Deaths.age_2), min_COVID.19.Deaths := min_COVID.19.Deaths.age_1+min_COVID.19.Deaths.age_2]
  
  tmp1[is.na(COVID.19.Deaths.age_1) & COVID.19.Deaths.age_2 > 0, max_COVID.19.Deaths := COVID.19.Deaths.age_2 + max_COVID.19.Deaths.age_1]
  tmp1[is.na(COVID.19.Deaths.age_1) & COVID.19.Deaths.age_2 > 0, min_COVID.19.Deaths := COVID.19.Deaths.age_2 + min_COVID.19.Deaths.age_1]
  
  tmp1[COVID.19.Deaths.age_1 > 0 & is.na(COVID.19.Deaths.age_2), max_COVID.19.Deaths := COVID.19.Deaths.age_1 + max_COVID.19.Deaths.age_2]
  tmp1[COVID.19.Deaths.age_1 > 0 & is.na(COVID.19.Deaths.age_2), min_COVID.19.Deaths := COVID.19.Deaths.age_1 + min_COVID.19.Deaths.age_2]
  
  tmp1[COVID.19.Deaths.age_1 > 0 & COVID.19.Deaths.age_2 > 0, COVID.19.Deaths := COVID.19.Deaths.age_1 + COVID.19.Deaths.age_2]
  tmp1[, Age.group := age_output]
  
  tmp = rbind(tmp, select(tmp1, 'date', 'State', 'Age.group', 'min_COVID.19.Deaths', 'max_COVID.19.Deaths', 'COVID.19.Deaths', 'Sex'))
  tmp = rbind(tmp, tmp_p)
  tmp = tmp[order(State, Age.group, date)]
  
  # ensuring that min and max are strictly increasing over time
  tmp2 = subset(tmp, is.na(COVID.19.Deaths))
  tmp2[, is.min_COVID.19.Deaths.sorted := min_COVID.19.Deaths == sort(min_COVID.19.Deaths), by = c('State', 'Age.group')]
  tmp2[, is.max_COVID.19.Deaths.sorted := max_COVID.19.Deaths == sort(max_COVID.19.Deaths), by = c('State', 'Age.group')]
  stopifnot(all(tmp2$is.min_COVID.19.Deaths.sorted == T) & all(tmp2$is.max_COVID.19.Deaths.sorted == T))

  return(tmp)
}

find_daily_deaths = function(tmp)
  {

  # ensure incrinsing cumulative deaths
  tmp = ensure_increasing_cumulative_deaths(tmp)
  
  # find date index with NA
  tmp1 = tmp[, list(idx_last_NA = which(is.na(COVID.19.Deaths))), by = c("loc_label", 'age')]
  tmp2 = tmp1[, list(min_idx_last_NA = min(idx_last_NA), max_idx_last_NA = max(idx_last_NA)), by = c("loc_label", 'age')]
  tmp1 = unique(select(tmp, "loc_label", 'age'))
  tmp2 = merge(tmp1, tmp2, by = c("loc_label", 'age'), all.x = T)
  tmp = merge(tmp, tmp2, by = c("loc_label", 'age'))
  tmp[, date_idx := 1:length(date), by = c("loc_label", 'age')]
  
  # find daily deaths
  tmp[, daily.deaths := c(NA, diff(COVID.19.Deaths))]
  tmp[, daily.deaths := as.numeric(daily.deaths)]
  tmp[, min.daily.deaths := NA]
  tmp[, min.daily.deaths := as.numeric(min.daily.deaths)]
  tmp[, max.daily.deaths := NA]
  tmp[, max.daily.deaths := as.numeric(max.daily.deaths)]
  
  # first day, daily death is NA
  tmp[date_idx == 1, daily.deaths := NA]
  
  # daily boundaries deaths if NA
  # first day of NA
  tmp[date_idx == min_idx_last_NA & date_idx != 1, min.daily.deaths := min_COVID.19.Deaths]
  tmp[date_idx == min_idx_last_NA & date_idx != 1, max.daily.deaths := max_COVID.19.Deaths]
  tmp[date_idx == min_idx_last_NA & date_idx == 1, min.daily.deaths := NA]
  tmp[date_idx == min_idx_last_NA & date_idx == 1, max.daily.deaths := NA]
  # between the boundaries
  tmp[date_idx != min_idx_last_NA, min.daily.deaths := 0]
  tmp[date_idx != min_idx_last_NA, max.daily.deaths := max_COVID.19.Deaths-1]
  # last day after NA
  tmp[date_idx == max_idx_last_NA+1, min.daily.deaths := 1]
  tmp[date_idx == max_idx_last_NA+1, max.daily.deaths := max_COVID.19.Deaths-1]
  
  stopifnot(nrow(tmp[daily.deaths < 0]) == 0)
  
  tmp = select(tmp, -COVID.19.Deaths, -min_COVID.19.Deaths, -max_COVID.19.Deaths, -min_idx_last_NA, -max_idx_last_NA, -date_idx)
  
  # remove first date 
  dates = sort(unique(tmp$date))
  tmp = subset(tmp, date != dates[1])
  
  return(tmp)
}

ensure_increasing_cumulative_deaths_origin = function(tmp)
  {
  
  #
  # check if cumulative death is strictly decreasing from last date to first date
  for(Code in unique(tmp$State)){
    for(age_group in unique(tmp$Age.group)){
      
      tmp1 = subset(tmp, Age.group == age_group & State == Code)
      dates = unique(tmp1$date)
      
      for(t in 1:length(dates)){
        
        Date = rev(dates)[t]
        #print(Date)
        
        if(Date < max(dates)){
          
          if(is.na(tmp[Age.group == age_group & date == Date & State == Code, COVID.19.Deaths]))
            next
          if(is.na(tmp[Age.group == age_group & date == rev(dates)[t-1] & State == Code, COVID.19.Deaths]))
            next
          
          # if cumulative date at date t < date t - 1, fix cum deaths at date t - 1 to the one at date t.
          if(tmp[Age.group == age_group & date == Date & State == Code, COVID.19.Deaths] > tmp[Age.group == age_group & date == rev(dates)[t-1] & State == Code, COVID.19.Deaths]){
            tmp[Age.group == age_group & date == Date & State == Code,]$COVID.19.Deaths = tmp[Age.group == age_group & date == rev(dates)[t-1] & State == Code, COVID.19.Deaths]
          }
          
        }
        
      }
    }
  }
  
  
  return(tmp)
}

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

bugfix_nonincreasing_cumulative_deaths = function(tmp)
  {
  # notices non stricly increasing cum deaths
  
  if(unique(tmp$Sex) == 'Female'){
    tmp[State == 'Oregon' & Age.group == '40-49 years' & date == as.Date('2021-03-13')]$COVID.19.Deaths = 14 
    # tmp[State == 'Colorado' & Age.group == '30-49 years' & date == as.Date('2020-09-19')]$COVID.19.Deaths = 15 
    # tmp[State == 'Colorado' & Age.group == '65-74 years' & date == as.Date('2020-09-19')]$COVID.19.Deaths = 133 
    # tmp[State == 'Connecticut' & Age.group == '75-84 years' & date == as.Date('2020-09-12')]$COVID.19.Deaths = 576
    # tmp[State == 'Maine' & Age.group == '65-74 years' & date == as.Date('2020-10-10')]$COVID.19.Deaths = 10
    # tmp[State == 'New Mexico' & Age.group == '85 years and over' & date %in% c(as.Date('2020-09-26'), as.Date('2020-10-03'), as.Date('2020-10-10'))]$COVID.19.Deaths = 119
    # tmp[State == 'New Jersey' & Age.group == '30-49 years' & date == as.Date('2020-10-17')]$COVID.19.Deaths = 154
    # tmp[State == 'New York' & Age.group == '30-49 years' & date == as.Date('2020-11-14')]$COVID.19.Deaths = 120
    # tmp[State == 'South Dakota' & Age.group == '50-64 years' & date == as.Date('2020-10-17')]$COVID.19.Deaths = 19
    # tmp[State == 'Utah' & Age.group == '75-84 years' & date == as.Date('2021-03-20')]$COVID.19.Deaths = 227
    # tmp[State == 'Vermont' & Age.group == '75-84 years' & date == as.Date('2020-12-05')]$COVID.19.Deaths = 11
    # tmp[State == 'West Virginia' & Age.group == '75-84 years' & date == as.Date('2020-11-14')]$COVID.19.Deaths = 59
    # 
  }

  return(tmp)
}

merge_deathByAge_over_Sex = function(tmp1, tmp2)
  {
  
  setnames(tmp1, c('daily.deaths', 'min.daily.deaths', 'max.daily.deaths'), c('daily.deaths.sex_1', 'min.daily.deaths.sex_1', 'max.daily.deaths.sex_1'))
  setnames(tmp2, c('daily.deaths', 'min.daily.deaths', 'max.daily.deaths'), c('daily.deaths.sex_2', 'min.daily.deaths.sex_2', 'max.daily.deaths.sex_2'))
  
  tmp = unique(select(tmp1, loc_label, code, age, age_from, age_to))
  
  tmp1 = merge(tmp1, tmp2, by = c('age', 'date', 'loc_label'))
  
  tmp1[, daily.deaths := as.numeric(NA)]
  tmp1[, daily.deaths := as.numeric(daily.deaths)]
  tmp1[, min.daily.deaths := as.numeric(NA)]
  tmp1[, min.daily.deaths := as.numeric(min.daily.deaths)]
  tmp1[, max.daily.deaths := as.numeric(NA)]
  tmp1[, max.daily.deaths := as.numeric(max.daily.deaths)]
  
  tmp1[is.na(daily.deaths.sex_1) & is.na(daily.deaths.sex_2), max.daily.deaths := max.daily.deaths.sex_1 + max.daily.deaths.sex_2]
  tmp1[is.na(daily.deaths.sex_1) & is.na(daily.deaths.sex_2), min.daily.deaths := min.daily.deaths.sex_1 + min.daily.deaths.sex_2]
  
  tmp1[is.na(daily.deaths.sex_1) & daily.deaths.sex_2 >= 0, max.daily.deaths := max.daily.deaths.sex_1 + daily.deaths.sex_2]
  tmp1[is.na(daily.deaths.sex_1) & daily.deaths.sex_2 >= 0, min.daily.deaths := min.daily.deaths.sex_1 + daily.deaths.sex_2]
  
  tmp1[daily.deaths.sex_1 >= 0 & is.na(daily.deaths.sex_2), max.daily.deaths := daily.deaths.sex_1 + max.daily.deaths.sex_2]
  tmp1[daily.deaths.sex_1 >= 0 & is.na(daily.deaths.sex_2), min.daily.deaths := daily.deaths.sex_1 + min.daily.deaths.sex_2]
  
  tmp1[daily.deaths.sex_1 >= 0 & daily.deaths.sex_2 >= 0, daily.deaths := daily.deaths.sex_1 + daily.deaths.sex_2]
  
  tmp1 = select(tmp1, 'date', 'loc_label', 'age', 'min.daily.deaths', 'max.daily.deaths', 'daily.deaths')
  
  tmp = merge(tmp, tmp1, by = c('age', 'loc_label'))
  
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
