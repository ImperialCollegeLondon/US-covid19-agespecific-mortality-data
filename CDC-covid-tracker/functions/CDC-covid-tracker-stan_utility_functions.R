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

plot_continuous_age_contribution = function(fit, df_age_continuous, df_week, lab, outdir){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- c('M','CL','CU')
  
  if(is.null(fit)) return(ggplot())
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  tmp1 = as.data.table( reshape2::melt(fit_samples$alpha) )
  setnames(tmp1, c('Var2', 'Var3'), c('age_index','week_index'))
  tmp1 = tmp1[, list( 	q= quantile(value, prob=ps),
                       q_label=p_labs), 
              by=c('age_index', 'week_index')]	
  tmp1 = dcast(tmp1, week_index + age_index ~ q_label, value.var = "q")
  
  tmp1 = merge(tmp1, df_week, by = 'week_index')
  tmp1[, age := df_age_continuous$age_index[age_index]]
  
  n_row = length(unique(tmp1$date))
   
  p = ggplot(tmp1, aes(x = age)) + 
    geom_line(aes(y = M)) +
    geom_ribbon(aes(ymin= CL, ymax = CU), alpha = 0.5) + 
    theme_bw() +
    labs(y = paste0("Relative contribution to ", lab), x = "", title = paste(Code)) + 
    facet_wrap(~date, nrow = n_row)
  
  ggsave(p, file = paste0(outdir, "-continuous_contribution_",Code, ".png") , w= 8, h = 6*n_row / 2)
  
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

make_convergence_diagnostics_plots = function(fit, title, suffix, outfile)
  {
  
  stopifnot(!is.null(fit))
  
  posterior <- as.array(fit)
  
  if(all(sapply(c("lambda", "nu", "rho", "sigma"), function(x) sum(grepl(x, names(fit))) > 0))){
    pars = c("lambda", "nu", "rho", "sigma")
  }
  
  if(all(sapply(c("beta", "nu", "lambda"), function(x) sum(grepl(x, names(fit))) > 0))){
    pars = c("beta", "nu", "lambda")
  }

  for(par in pars)
  {
    p_trace = bayesplot::mcmc_trace(posterior, regex_pars = par) + labs(title = title) 
    p_pairs = gridExtra::arrangeGrob(bayesplot::mcmc_pairs(posterior, regex_pars = par), top = title)
    p_intervals = bayesplot::mcmc_intervals(posterior, regex_pars = par, prob = 0.95,
                                            prob_outer = 0.95) + labs(title = title)
    
    ggsave(p_trace, file = paste0(outfile, "trace_plots_", suffix, '_', Code, "_", par,".png") , w= 10, h = 10)
    ggsave(p_pairs, file =  paste0(outfile, "pairs_plots_",  suffix, '_',Code, "_", par,".png") , w= 15, h = 15)
    ggsave(p_intervals, file = paste0(outfile, "intervals_plots_",  suffix, '_',Code, "_", par,".png") , w=10, h = 10)
    
  }

}

plot_posterior_predictive_checks = function(data, variable, variable_abbr, lab, outdir)
  {
  
  Code = unique(data$code)
  n_row = length(unique(data$date))
  
  # posterior predictive check
  p1 = ggplot(data, aes(x = age)) + 
    geom_point(aes(y = get(paste0("M_",variable_abbr)) ), col = "black")+
    geom_errorbar(aes(ymin = get(paste0("CL_",variable_abbr)), ymax = get(paste0("CU_",variable_abbr))), width = .2, col = "black")+
    geom_point(aes(y = get(variable)), col = "red") + 
    theme_bw() +
    labs(y = lab, x = "") + 
    facet_wrap(~date, nrow = n_row)
  
  ggsave(p1, file = paste0(outdir, "-posterior_predictive_checks_", Code,".png") , w= 10, h = 6*n_row / 2, limitsize = FALSE)

}

