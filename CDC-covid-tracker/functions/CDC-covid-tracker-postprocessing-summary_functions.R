make_predictive_checks_table = function(fit, variable_abbr, df_week, df_age_reporting, data){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_", variable_abbr)
  
  if(is.null(fit)) stop()
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  tmp1 = as.data.table( reshape2::melt(fit_samples$deaths_predict_state_age_strata) )
  setnames(tmp1, c('Var2', 'Var3'), c('age_index','week_index'))
  tmp1 = tmp1[, list( 	q= quantile(value, prob=ps),
                       q_label=p_labs), 
              by=c('age_index', 'week_index')]	
  tmp1 = dcast(tmp1, week_index + age_index ~ q_label, value.var = "q")
  
  tmp1 = merge(tmp1, df_week, by = 'week_index')
  tmp1[, age := df_state_age_strata$age[age_index]]
  
  tmp1 = merge(tmp1, data, by = c('date', 'age'))
  
  return(tmp1)
}

make_convergence_diagnostics_stats = function(fit){
  
  stopifnot(!is.null(fit))
  
  summary = rstan::summary(fit_cum)$summary
  eff_sample_size_cum <<- summary[,9][!is.na(summary[,9])]
  Rhat_cum <<- summary[,10][!is.na(summary[,10])]
  cat("the minimum and maximum effective sample size are ", range(eff_sample_size_cum), "\n")
  cat("the minimum and maximum Rhat are ", range(Rhat_cum), "\n")
  if(min(eff_sample_size_cum) < 500) cat('\nEffective sample size smaller than 500 \n')
  
  #
  # compute WAIC and LOO
  re = rstan::extract(fit_cum)
  if('log_lik' %in% names(re)){
    log_lik <- loo::extract_log_lik(fit_cum)
    .WAIC = loo::waic(log_lik)
    .LOO = loo::loo(log_lik)
    print(.WAIC); print(.LOO)
    WAIC <<- .WAIC$pointwise
    LOO <<- .LOO$pointwise
  } 
}
