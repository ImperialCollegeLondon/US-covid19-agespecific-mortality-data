library(tidyr)
library(dplyr)

read_pop_count_by_age_us = function(path_to_file)
  {
  pop_by_age <- readRDS(path_to_file)
  pop_by_age <- dplyr::select(pop_by_age[which(!is.na(pop_by_age$code)),], -Total) %>%
    reshape2::melt(id.vars = c("Region", "code")) %>%
    dplyr::rename(age = variable, pop = value, state = Region)
  
  pop_by_age <- pop_by_age %>%
    dplyr::group_by(state) %>%
    dplyr::summarise(pop_sum:= sum(pop))	%>%
    dplyr::inner_join(pop_by_age) %>%
    dplyr::mutate(pop= pop/pop_sum) 	
  
  return(pop_by_age)
}

summarise_DeathByAge = function(tmp, pop_info)
  {
  
  #
  # Find observation period and number of age groups by location
  tmp = tmp[, .N, by=.(code, date)]
  tmp = tmp[, list(min_date = min(date), 
                   max_date = max(date),
                   n_days = length(seq.Date(min(date), max(date), by = "days"))), by = c("code", "N")]
  setnames(tmp, "N", "n_age_groups")

  tmp[, max_date := as.character(format(max_date, "%B %d, %Y"))]
  tmp[, min_date := as.character(format(min_date, "%B %d, %Y"))]
  
  #
  # Find missing location labels
  tmp = merge(tmp, pop_info, by = c("code"), all.y = T)
  
  #
  # Clean
  tmp = replace_na(tmp, list(min_date = "-", max_date = "-", n_days = "-", n_age_groups  = "-"))
  tmp = tmp[order(loc_label)]
  tmp = select(tmp, c("loc_label", "min_date", "max_date", "n_days", "n_age_groups", "code"))
  
  return(tmp)
}

adjust_age_bands = function(deathByAge)
  {
  
  #
  # Find closest 5 year age bands to match population count
  deathByAge = select(deathByAge, -loc_label)
  deathByAge = adjust_to_5y_age_band(deathByAge)

  #
  # Group age band with age from > 80,85 as 80+,85+
  df = vector(mode = "list", length = length(unique(deathByAge$code)))
  for(i in 1:length(unique(deathByAge$code))){
    Code = unique(deathByAge$code)[i]
    
    tmp = subset(deathByAge, code == Code)
    tmp[all(c("90-99", "100+", "80-89") %in% age), age := ifelse(age %in% c("90-99", "100+", "80-89") ,"80+", age)]
    tmp[all(c("90+", "80-89") %in% age), age := ifelse(age %in% c("90+", "80-89") ,"80+", age)]
    tmp[all(c("85-89", "90+") %in% age), age := ifelse(age %in% c("85-89", "90+") ,"85+", age)]
    
    df[[i]] = copy(tmp)
  }
  deathByAge = do.call("rbind", df)
  deathByAge = deathByAge[, list(cum.deaths = sum(cum.deaths), 
                    daily.deaths = sum(daily.deaths)), by = c("age", "code", "date")]
  
  
  deathByAge = deathByAge[order(code, date)]
  
  return(deathByAge)
}

find_reporting_data_format_statistics = function(tmp, last_Date, death_data)
{
  
  # numbers of locations included
  code = unique(tmp$code)
  loc_included = length(code)
  
  if(all(c("NYC", "DC") %in% code)){
    loc_included = loc_included -2 
    loc_included_txt = paste0(loc_included, " US states, New York City and the District of Columbia") 
  } else if("DC" %in% code){
    loc_included = loc_included-1
    loc_included_txt = paste0(loc_included, " US states and the District of Columbia") 
  } else if("NYC" %in% code){
    loc_included = loc_included-1
    loc_included_txt = paste0(loc_included, " US states and New York City") 
  } else{
    loc_included_txt = paste0(loc_included, " US states") 
  }
  
  # min and max date regardless of state 
  min_date = format(min(tmp$date), "%B %d, %Y");  
  max_date = format(max(tmp$date), "%B %d, %Y"); 
  
  # observed days
  tmp1 = unique(select(tmp, code, date, age))
  n_days = length(unique(tmp1$date))
  n_obs_days = nrow(tmp1)

  # comparison to the number of death reported by jhu
  jhu_data = subset(death_data, code != "NYC")
  if(max(jhu_data$date) < max(tmp$date)) stop("Update JHU first")
  jhu_data = subset(jhu_data, code %in% unique(tmp1$code) & date <= max(tmp$date))
  tmp1 = unique(select(jhu_data, code, date))
  n_days_jhu = length(unique(tmp1$date))
  n_obs_days_jhu = nrow(tmp1)
  prop_obs_days_vs_jhu = round((n_obs_days / n_obs_days_jhu)*100, digits = 2)
  last_common_day = format(max(tmp1$date), "%B %d, %Y")
  
  return(list(list(loc_included, loc_included_txt),
              list(min_date, max_date, format(as.Date(last_Date), "%B %d, %Y")),
              list(prettyNum(n_days,big.mark=","), prettyNum(n_obs_days,big.mark=",")),
              list(prettyNum(n_days_jhu,big.mark=","), prettyNum(n_obs_days_jhu,big.mark=","), prop_obs_days_vs_jhu, last_common_day)))
}

find_pop_count = function(deathByAge, pop_count){
  
  #
  # Match population count 
  deathByAge[, age_from := as.numeric(ifelse(grepl("\\+", age), gsub("(.+)\\+", "\\1", age), gsub("(.+)-.*", "\\1", age)))]
  deathByAge[, age_to := as.numeric(ifelse(grepl("\\+", age), 100, gsub(".*-(.+)", "\\1", age)))]
  pop_count[, age_from := as.numeric(ifelse(grepl("\\+", age), gsub("(.+)\\+", "\\1", age), gsub("(.+)-.*", "\\1", age)))]
  pop_count[, age_to := as.numeric(ifelse(grepl("\\+", age), 100, gsub(".*-(.+)", "\\1", age)))]
  
  df = vector(mode = "list", length = length(unique(deathByAge$code)))
  for(i in 1:length(unique(deathByAge$code))){
    Code = unique(deathByAge$code)[i]
    
    tmp = subset(deathByAge, code == Code)
    tmp1 = subset(pop_count, code == Code)
    tmp2 = tmp[, list(pop = sum( tmp1$pop[which(tmp1$age_from == age_from):which(tmp1$age_to == age_to)] )), by = c("code", "date", "age", "age_from", "age_to")]
    tmp = merge(tmp, tmp2, by = c("code", "date", "age", "age_from", "age_to"))
    tmp[, pop_sum := unique(tmp1$pop_sum) ]
    tmp[, loc_label := unique(tmp1$loc_label) ]
    
    df[[i]] = copy(tmp)
  }
  df = do.call("rbind", df)
  df[, pop_count := pop * pop_sum]
  df = select(df, -c(pop, pop_sum))
  
}

find_time_index_since_nth_cum_death = function(death_summary, path.to.jhu.data, path.to.nyc.data, n){
  jhu_data = as.data.table( readRDS(path.to.jhu.data) )
  nyc_data = as.data.table( read.csv(path.to.nyc.data) )
  
  #
  # Find data where cum death >= 10 
  jhu_data[, over.n.cum.deaths := cumulative_deaths >= n]
  tmp = subset(jhu_data, over.n.cum.deaths == 1)
  tmp = tmp[, list(first_date_nthcum_death = min(date)), by = "code"]
  
  #
  # Same for NYC
  nyc_data[, cum_deaths := cumsum(DEATH_COUNT)]
  nyc_data[, over.n.cum.deaths := cum_deaths >= n]
  tmp1 = subset(nyc_data, over.n.cum.deaths == 1)[1]
  tmp = rbind(tmp, data.table(code = "NYC", first_date_nthcum_death = as.Date(tmp1$date_of_interest, format = "%m/%d/%Y") ))

  #
  # Find time since 10th cum death in the prediction
  tmp = merge(death_summary, tmp, by = "code")
  tmp[, time_since_nth_cum_deaths :=  date - first_date_nthcum_death, by = "code"]
  
  return(tmp)
}

find_reporting_mortality_counts_statistics = function(tmp, tmp2){
  
  # population counts
  tmp2[, pop_count := pop * pop_sum]
  tmp2 = tmp2[, list(pop_count = sum(pop_count)), by = c("loc_label", "code")]
   
  # covid-19 atrributable deaths
  tmp1 = tmp[, list(total_count = sum(cum.deaths)), by = c("code")]
  tmp1 = merge(tmp1, tmp2, by = "code")
  tmp1 = tmp1[order(total_count, decreasing = T)]
  tmp1[, mortality_contribution := total_count / sum(tmp1$total_count)]
  tmp1[, pop_contribution := pop_count / sum(tmp1$pop_count)]
  
  # in the US
  counts_US = copy(tmp1)
  counts_US[, total_count := prettyNum(total_count,big.mark=",")]
  counts_US[, mortality_contribution := round(mortality_contribution*100, digits = 2)]
  counts_US[, pop_contribution := round(pop_contribution*100, digits = 2)]
  counts_US = select(counts_US, loc_label, total_count)
  # 5 states with most covid-19 atrributable deaths
  counts_5 = tmp1[1:5,]
  count_5_stats = counts_5[, list(total_count = sum(total_count), pop_contribution = sum(pop_contribution), mortality_contribution = sum(mortality_contribution))]
  count_5_stats[, mortality_contribution := round(mortality_contribution*100, digits = 2)]
  count_5_stats[, pop_contribution := round(pop_contribution*100, digits = 2)]
  
  return(list(counts_US,count_5_stats))
}

find_share_age_deaths = function(tmp, Age){
  
  tmp1 = select(tmp, code, loc_label, division, age, CL_deaths_prop_cum, CU_deaths_prop_cum,  M_deaths_prop_cum, pop_count)
  # total population US
  tmp2 = tmp1[, list(total_pop_count_US = sum(pop_count))]
  tmp1$total_pop_count_US  = tmp2$total_pop_count_US
  # total population by division
  tmp2 = tmp1[, list(total_pop_count_division = sum(pop_count)), by = "division"]
  tmp1 = merge(tmp1, tmp2, by = "division")
  # total population by state
  tmp2 = tmp1[, list(total_pop_count_state = sum(pop_count)), by = "code"]
  tmp1 = merge(tmp1, tmp2, by = "code")
  
  
  # contribution of age group Age national level
  tmp2 = subset(tmp1, age == Age)
  
  # by location
  state_age_share = select(tmp2, loc_label, M_deaths_prop_cum, CL_deaths_prop_cum, CU_deaths_prop_cum, pop_count, total_pop_count_state)
  state_age_share[, report_share := paste0( round(M_deaths_prop_cum*100, digits = 2), '\\% [', round(CL_deaths_prop_cum*100, digits = 2), "-", round(CU_deaths_prop_cum*100, digits = 2), "]")]
  state_age_share[, prop_pop_count := round((pop_count/total_pop_count_state)*100, digits = 2)]
  state_age_share = state_age_share[order(M_deaths_prop_cum, decreasing = T)]
  state_age_share = select(state_age_share, loc_label, report_share, prop_pop_count)
  
  # by division
  division_age_share = select(tmp2, M_deaths_prop_cum, CL_deaths_prop_cum, CU_deaths_prop_cum, pop_count, total_pop_count_division, division)
  division_age_share = division_age_share[, list(M_prop_tot = round(mean(M_deaths_prop_cum)*100, digits = 2), 
                                  CL_prop_tot = round(mean(CL_deaths_prop_cum)*100, digits = 2), 
                                  CU_prop_tot = round(mean(CU_deaths_prop_cum)*100, digits = 2), 
                                  prop_pop_count_tot = round(sum(pop_count / total_pop_count_division)*100, digits = 2)), by = "division"]
  division_age_share[, report_share := paste0(M_prop_tot, '\\% [', CL_prop_tot, '-', CU_prop_tot, ']')]
  division_age_share = division_age_share[order(M_prop_tot, decreasing = T)]
  division_age_share = select(division_age_share, division, report_share, prop_pop_count_tot)
  
  # nationally
  national_age_share = select(tmp2, M_deaths_prop_cum, CL_deaths_prop_cum, CU_deaths_prop_cum, pop_count, total_pop_count_US)
  national_age_share = national_age_share[, list(M_prop_tot = round(mean(M_deaths_prop_cum)*100, digits = 2), 
                                  CL_prop_tot = round(mean(CL_deaths_prop_cum)*100, digits = 2), 
                                  CU_prop_tot = round(mean(CU_deaths_prop_cum)*100, digits = 2), 
                                  prop_pop_count_tot = round(sum(pop_count/total_pop_count_US)*100, digits = 2))]
  national_age_share[, report_share := paste0(M_prop_tot, '\\% [', CL_prop_tot, '-', CU_prop_tot, ']')]
  national_age_share = select(national_age_share, report_share, prop_pop_count_tot)
  
  return(list(state_age_share, division_age_share, national_age_share))
}

find_mortality_rate_report = function(tmp, Age){
  
  mortality_rate_100K_nationally = tmp[, list(CL_deaths_cum = sum(CL_deaths_cum), CU_deaths_cum = sum(CU_deaths_cum), M_deaths_cum = sum(M_deaths_cum), pop_count = sum(pop_count)), by = c("age", "date")]
  mortality_rate_100K_nationally[, M_deaths_cum_100K := M_deaths_cum * 100000 / pop_count]
  mortality_rate_100K_nationally[, CL_deaths_cum_100K := CL_deaths_cum * 100000 / pop_count]
  mortality_rate_100K_nationally[, CU_deaths_cum_100K := CU_deaths_cum * 100000 / pop_count]
  mortality_rate_100K_nationally[, report := paste0(round(M_deaths_cum_100K, digits = 2), ' [', round(CL_deaths_cum_100K, digits = 2), '-', round(CU_deaths_cum_100K, digits = 2), ']')]
  mortality_rate_100K_nationally = dcast(mortality_rate_100K_nationally, .~ age, value.var = "report")[,-1]
  
  mortality_rate_state = subset(tmp, age == Age)
  mortality_rate_state[, report_100K := paste0(prettyNum(round(M_deaths_cum_100K, digits = 2),big.mark=","), ' [', prettyNum(round(CL_deaths_cum_100K, digits = 2),big.mark=","), '-', prettyNum(round(CU_deaths_cum_100K, digits = 2),big.mark=","), ']')]
  mortality_rate_state[, report_1 := paste0(round(M_mortality_rate*100, digits = 2), '\\% [', round(CL_mortality_rate*100, digits = 2), '-', round(CU_mortality_rate*100, digits = 2), ']')]
  mortality_rate_state[, report_cum := paste0(prettyNum(round(M_deaths_cum),big.mark=","), ' [', prettyNum(round(CL_deaths_cum),big.mark=","), '-', prettyNum(round(CU_deaths_cum),big.mark=","), ']')]
  mortality_rate_state[, pop_count := prettyNum(pop_count,big.mark=",")]
  mortality_rate_state = mortality_rate_state[order(M_mortality_rate, decreasing = T)]
  mortality_rate_state = select(mortality_rate_state, loc_label, report_1, report_100K, report_cum, pop_count)
  
  return(list(mortality_rate_100K_nationally, mortality_rate_state))
}

find_mortality_counts_rate_summary = function(death_summary_last_month, Age, pop_count){
  tmp = subset(death_summary_last_month, age == Age)
  tmp[, report_cum := paste0(prettyNum(round(M_deaths_cum),big.mark=","), ' [', prettyNum(round(CL_deaths_cum),big.mark=","), '-', prettyNum(round(CU_deaths_cum),big.mark=","), ']')]
  tmp[, report_100K := paste0(prettyNum(round(M_deaths_cum_100K, digits = 2),big.mark=","), ' [', prettyNum(round(CL_deaths_cum_100K, digits = 2),big.mark=","), '-', prettyNum(round(CU_deaths_cum_100K, digits = 2),big.mark=","), ']')]
  tmp[, report_1 := paste0(format(round(M_mortality_rate*100, digits = 2), nsmall = 2), '\\% [', format(round(CL_mortality_rate*100, digits = 2), nsmall = 2), '-', format(round(CU_mortality_rate*100, digits = 2), nsmall = 2), ']')]
  tmp[, pop_count := prettyNum(pop_count,big.mark=",")]
  tmp = select(tmp, loc_label, report_cum, report_1, report_100K, pop_count)
  
  # merge to pop_count to get all alabels
  tmp1 = unique(select(pop_count, loc_label))
  tmp = merge(tmp, tmp1, by = "loc_label", all.y = T)
  tmp[is.na(tmp)] = "-"
  
  return(tmp)
}

prepare_CDC_data = function(last.day,indir){
  
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
  
  tmp1 = tmp[, list(N = .N), by = c('State', 'date')]
  stopifnot(all(tmp1$N == 11))
  
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
