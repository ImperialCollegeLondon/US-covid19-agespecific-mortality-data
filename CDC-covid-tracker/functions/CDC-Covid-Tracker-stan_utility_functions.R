make_predictive_checks_table_CDC = function(fit, variable_abbr, tmp1, df_age_reporting, no_fit){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_", variable_abbr)
  
  # if no fit was done because the sum of the deaths were <1 
  if(no_fit){
    df_age_reporting = select(df_age_reporting, -age_index, -age_from_index, -age_to_index)
    tmp2 = merge(tmp1, df_age_reporting, by.x = c('age_from', 'age_to', 'age'), by.y = c('age_from', 'age_to', 'age_cat'), all.y = T)
    tmp2[, paste0(c('M','CL','CU'), "_", variable_abbr) := NA]
    
    tmp2[, loc_label := unique(loc_label[!is.na(loc_label)])]
    tmp2[, date := unique(date[!is.na(date)])]
    tmp2[, code := unique(code[!is.na(code)])]
    
    tmp2[,age := factor(age, levels = unique(tmp[order(age_from)]$age)) ]
    return(tmp2)
  }
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  # posterior predictive check
  tmp2 = as.data.table( reshape2::melt(fit_samples$deaths_predict_state_age_strata) )
  colnames(tmp2) = c("iterations", "age_index", "value")
  tmp2 = tmp2[, list( 	q= quantile(value, prob=ps),
                       q_label=p_labs), 
              by=c('age_index')]		
  tmp2[, age := df_age_reporting$age_cat[age_index]]
  tmp2[, age_from := df_age_reporting$age_from[age_index] ]
  tmp2[, age_to := df_age_reporting$age_to[age_index] ]
  tmp2 = dcast(tmp2, age + age_from + age_to ~ q_label, value.var = "q")
  tmp2 = merge(tmp2, tmp1, by = c("age", 'age_from', 'age_to'), all.x = T)
  
  tmp2[,age := factor(age, levels = unique(tmp[order(age_from)]$age)) ]
  
  tmp2[, loc_label := unique(loc_label[!is.na(loc_label)])]
  tmp2[, date := unique(date[!is.na(date)])]
  tmp2[, code := unique(code[!is.na(code)])]
  
  return(tmp2)
}

plot_continuous_age_contribution_CDC = function(fit, df_age, lab, Code, Date, no_fit){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- c('M','CL','CU')
  
  if(no_fit) return(ggplot())
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  # pi: age contribution to deaths (continuous)
  tmp3 = as.data.table(  reshape2::melt(fit_samples$alpha) ) 
  colnames(tmp3) = c("iterations", "age_index", "value")
  tmp3 = tmp3[, list( 	q= quantile(value, prob=ps),
                       q_label=p_labs), 
              by=c('age_index')]	
  tmp3 = merge(tmp3, df_age, by = "age_index")
  tmp3 = dcast(tmp3, age ~ q_label, value.var = "q")
  p = ggplot(tmp3, aes(x = age)) + 
    geom_line(aes(y = M)) +
    geom_ribbon(aes(ymin= CL, ymax = CU), alpha = 0.5) + 
    theme_bw() +
    labs(y = paste0("Relative contribution to ", lab), x = "", title = paste(Code, "date", Date))
  
  return(p)
}
