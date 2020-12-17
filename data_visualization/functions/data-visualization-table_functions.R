make_mortality_rate_proportion_by_age_table = function(deaths_summary_four_age_bands_last_day, Age_cat){
  tmp = subset(deaths_summary_four_age_bands_last_day, age_cat == Age_cat)
  
  tmp = select(tmp, loc_label, mortality_rate, prop_cum.deaths)
  tmp[, mortality_rate := paste0(sprintf("%.2f", mortality_rate*100), '\\%')]
  tmp[, prop_cum.deaths := paste0(sprintf("%.2f", prop_cum.deaths*100), '\\%')]
  
  #
  # Create table
  tmp = merge(tmp, unique(select(pop_count, loc_label)), by = "loc_label", all.x = T, all.y = T)
  tmp = tmp[order(loc_label)]
  tmp = rbind(tmp[loc_label == "All locations"], tmp[loc_label != "All locations"])
  tmp = replace_na(tmp, list(mortality_rate = "-", prop_cum.deaths = "-"))
  
  return(tmp)
}

