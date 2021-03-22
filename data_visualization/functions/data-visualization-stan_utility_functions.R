plot_posterior_predictive_checks = function(tmp2, variable, variable_abbr, lab, Code, Month){
  
  plot.new()
  
  # posterior predictive check
  p1 = ggplot(tmp2, aes(x = age)) + 
    geom_point(aes(y = get(paste0("M_",variable_abbr)) ), col = "black")+
    geom_errorbar(aes(ymin = get(paste0("CL_",variable_abbr)), ymax = get(paste0("CU_",variable_abbr))), width = .2, col = "black")+
    geom_point(aes(y = get(variable)), col = "red") + 
    theme_bw() +
    labs(y = lab, x = "")
  p2 = ggplot(tmp2, aes(x = age)) +
    geom_point(aes(y = get(paste0("M_",variable_abbr))), col = "black")+
    geom_errorbar(aes(ymin = get(paste0("CL_",variable_abbr)), ymax = get(paste0("CU_",variable_abbr))), width = .2, col = "black")+
    geom_point(aes(y = get(variable)), col = "red") +
    theme_bw() +
    scale_y_log10() +
    labs(y = lab, x = "")
  grid::grid.newpage()
  p3 = gridExtra::grid.arrange(p1, p2, nrow = 1, top = paste(Code, "month", Month))
  p4 = ggplot(tmp2, aes(x = get(variable), y = get(paste0("M_",variable_abbr)), col = age)) +
    geom_point() +
    geom_errorbar(aes(ymin = get(paste0("CL_",variable_abbr)), ymax = get(paste0("CU_",variable_abbr))), width = .2, alpha = 0.5, col = "black") +
    theme_bw() +
    labs(y = paste0("Predicted ", lab), x = paste0("Observed ", lab), title = paste(Code, "month", Month)) +
    geom_abline(slope = 1, linetype = "dashed") +
    scale_y_log10() +
    scale_x_log10()
  
  return(list(p3, p4))
}

plot_continuous_age_contribution = function(fit, df_age, lab, Code, Month){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- c('M','CL','CU')
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  # pi: age contribution to deaths (continuous)
  tmp3 = as.data.table(  reshape2::melt(fit_samples$pi_predict) ) 
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
    labs(y = paste0("Contribution to ", lab), x = "", title = paste(Code, "month", Month))
  
  return(p)
}

make_predictive_checks_table = function(fit, variable_abbr, tmp1, df_state_age_strata){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_", variable_abbr)
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  # posterior predictive check
  tmp2 = as.data.table( reshape2::melt(fit_samples$deaths_predict_state_age_strata) )
  colnames(tmp2) = c("iterations", "age_index", "value")
  tmp2 = tmp2[, list( 	q= quantile(value, prob=ps),
                       q_label=p_labs), 
              by=c('age_index')]		
  tmp2[, age := df_state_age_strata$age[age_index]]
  tmp2 = dcast(tmp2, age ~ q_label, value.var = "q")
  tmp2 = merge(tmp2, tmp1, by = c("age"))
  tmp2[,age := factor(age, levels = unique(tmp[order(age_from)]$age)) ]
  
  return(tmp2)
}



summarise_abs_deaths = function(fit, name_var, abbr_variable, df_age_strata = NULL, add_2049 = 0){
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_",abbr_variable)
  
  # if empty
  if(is.null(fit)){
    tmp = data.table(age_index = df_age_strata$age_index, `M` = NA, `CL` = NA, `CU` = NA)
    colnames(tmp)[2:4] = p_labs
    return(tmp)
  }
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  # deaths predicted 
  tmp = as.data.table( reshape2::melt(fit_samples[[name_var]]) )
  colnames(tmp) = c("iterations", "age_index",  "value")
  
  # create 0 age index for 20-49
  if(add_2049){
    tmp1 = subset(tmp, age_index %in% 3:4)
    tmp1 = tmp1[, list(value = sum(value), age_index = 0), by = "iterations"]
    tmp = rbind(tmp, tmp1 )
  }
  
  # summarise
  tmp = tmp[, list( 	q= quantile(value, prob=ps),
                     q_label=p_labs), 
            by=c('age_index')]		
  tmp = dcast(tmp, age_index ~ q_label, value.var = "q")
  
  return(select(tmp, all_of(p_labs), age_index))
}

summarise_prop_deaths = function(fit, name_var, abbr_variable, df_age_strata = NULL, add_2049 = 0){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_",abbr_variable)
  
  # if empty
  if(is.null(fit)){
    tmp = data.table(age_index = df_age_strata$age_index, `M` = NA, `CL` = NA, `CU` = NA)
    colnames(tmp)[2:4] = p_labs
    return(tmp)
  }
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  # deaths predicted 
  tmp = as.data.table( reshape2::melt(fit_samples[[name_var]]) )
  colnames(tmp) = c("iterations", "age_index",  "value")
  tmp = tmp[, n_value := sum(value) , by = c("iterations") ]
  
  # create 0 age index for 20-49
  if(add_2049){
    tmp1 = subset(tmp, age_index %in% 3:4)
    tmp1 = tmp1[, list(value = sum(value), age_index = 0), by = c("iterations", 'n_value')]
    tmp = rbind(tmp, tmp1 )
  }
  
  # summarise
  tmp[, value := value / n_value]
  tmp = tmp[, list( 	q= quantile(value, prob=ps),
                     q_label=p_labs), 
            by=c('age_index')]		
  tmp = dcast(tmp, age_index ~ q_label, value.var = "q")
  
  return(select(tmp, all_of(p_labs), age_index))
}

find_crude_prop_cases_monthly = function(fit, name_var, abbr_variable, df_age_strata, path.to.ifr.by.age, add_2049 = 0){
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_",abbr_variable)
  
  # if empty
  if(is.null(fit)){
    tmp2 = data.table(age_index = df_age_strata$age_index, `M` = NA, `CL` = NA, `CU` = NA)
    colnames(tmp2)[2:4] = p_labs
    return(tmp2)
  }
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  # aggregate ifr by age
  ifr.by.age = as.data.table( read.csv(path.to.ifr.by.age) )
  df = unique(select(df_age_strata, age_from, age_to, age_index))
  df = df[order(age_from)]
  max.age = max(ifr.by.age$age)
  ifr.by.age.agg = vector(mode = "list", length = nrow(df))
  for(i in 1:nrow(df)){
    ifr.by.age.agg[[i]] = ifr.by.age[ age >= df$age_from[i] & age <= min(df$age_to[i], max.age), -1][,list( ifr_mean = mean(ifr_mean))]
    ifr.by.age.agg[[i]]$age_index = df$age_index[i]
  }
  ifr.by.age.agg = do.call("rbind", ifr.by.age.agg)
  
  # death predicted at time t
  tmp = as.data.table( reshape2::melt(fit_samples[[name_var]]) )
  colnames(tmp) = c("iterations", "age_index",  "value")
  
  # merge ifr
  tmp = merge(tmp, ifr.by.age.agg, by = "age_index")
  
  # create 0 age index for 20-49
  if(add_2049){
    tmp1 = subset(tmp, age_index %in% 3:4)
    tmp1 = tmp1[, list(value = sum(value), ifr_mean = mean(ifr.by.age[age >= 20 & age <= 49]$ifr_mean), age_index = 0), by = c("iterations")]
    tmp = rbind(tmp, tmp1 )
  }
  
  # find crude estimate of cases
  tmp[, value := value / ifr_mean]
  
  # find crude estimate of proportion of cases
  tmp1 =  tmp[age_index != 0, list(n_value = sum(value)) , by = c("iterations") ]
  tmp = merge(tmp, tmp1, by = c("iterations"))
  tmp[, value := value / n_value]
  
  # summarise 
  tmp = tmp[, list( 	q= quantile(value, prob=ps),
                     q_label=p_labs), 
            by=c('age_index')]		
  tmp = dcast(tmp, age_index ~ q_label, value.var = "q")
  
  return(select(tmp, all_of(p_labs), age_index))
}

find_crude_cases_monthly = function(fit, name_var, abbr_variable, df_age_strata, path.to.ifr.by.age, add_2049 = 0){
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_",abbr_variable)
  
  # if empty
  if(is.null(fit)){
    tmp2 = data.table(age_index = df_age_strata$age_index, `M` = NA, `CL` = NA, `CU` = NA)
    colnames(tmp2)[2:4] = p_labs
    return(tmp2)
  }
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  # aggregate ifr by age
  ifr.by.age = as.data.table( read.csv(path.to.ifr.by.age) )
  df = unique(select(df_age_strata, age_from, age_to, age_index))
  df = df[order(age_from)]
  max.age = max(ifr.by.age$age)
  ifr.by.age.agg = vector(mode = "list", length = nrow(df))
  for(i in 1:nrow(df)){
    ifr.by.age.agg[[i]] = ifr.by.age[ age >= df$age_from[i] & age <= min(df$age_to[i], max.age), -1][,list( ifr_mean = mean(ifr_mean))]
    ifr.by.age.agg[[i]]$age_index = df$age_index[i]
  }
  ifr.by.age.agg = do.call("rbind", ifr.by.age.agg)
  
  # death predicted at time t
  tmp = as.data.table( reshape2::melt(fit_samples[[name_var]]) )
  colnames(tmp) = c("iterations", "age_index",  "value")
  
  # merge ifr
  tmp = merge(tmp, ifr.by.age.agg, by = "age_index")
  
  # create 0 age index for 20-49
  if(add_2049){
    tmp1 = subset(tmp, age_index %in% 3:4)
    tmp1 = tmp1[, list(value = sum(value), ifr_mean = mean(ifr.by.age[age >= 20 & age <= 49]$ifr_mean), age_index = 0), by = c("iterations")]
    tmp = rbind(tmp, tmp1 )
  }
  
  # find crude estimate of cases
  tmp[, value := value / ifr_mean]
  
  # summarise 
  tmp = tmp[, list( 	q= quantile(value, prob=ps),
                     q_label=p_labs), 
            by=c('age_index')]		
  tmp = dcast(tmp, age_index ~ q_label, value.var = "q")
  
  return(select(tmp, all_of(p_labs), age_index))
}

find_diff_deaths_monthly = function(fit_monthly_t, fit_monthly_t0, name_var, abbr_variable, df_age_strata = NULL, add_2049 = 0){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_",abbr_variable)
  
  # if empty
  if(is.null(fit_monthly_t) | is.null(fit_monthly_t0)){
    tmp2 = data.table(age_index = df_age_strata$age_index, `M` = NA, `CL` = NA, `CU` = NA)
    colnames(tmp2)[2:4] = p_labs
    return(tmp2)
  }
  
  # extract samples
  fit_samples_t = rstan::extract(fit_monthly_t)
  fit_samples_t0 = rstan::extract(fit_monthly_t0)
  
  # proportion of death predicted at time t
  tmpt = as.data.table( reshape2::melt(fit_samples_t[[name_var]]) )
  colnames(tmpt) = c("iterations", "age_index",  "value_t")
  tmpt = tmpt[, n_value := sum(value_t) , by = c("iterations") ]
  if(add_2049){
    tmp1 = subset(tmpt, age_index %in% 3:4)
    tmp1 = tmp1[, list(value_t = sum(value_t), age_index = 0), by = c("iterations", 'n_value')]
    tmpt = rbind(tmpt, tmp1 )
  }
  tmpt[, value_t := value_t / n_value]
  tmpt = select(tmpt, -n_value)
  
  # proportion of death predicted at time 0
  tmpt0 = as.data.table( reshape2::melt(fit_samples_t0[[name_var]]) )
  colnames(tmpt0) = c("iterations", "age_index",  "value_t0")
  tmpt0 = tmpt0[, n_value := sum(value_t0) , by = c("iterations") ]
  if(add_2049){
    tmp1 = subset(tmpt0, age_index %in% 3:4)
    tmp1 = tmp1[, list(value_t0 = sum(value_t0), age_index = 0), by = c("iterations", 'n_value')]
    tmpt0 = rbind(tmpt0, tmp1 )
  }
  tmpt0[, value_t0 := value_t0 / n_value]
  tmpt0 = select(tmpt0, -n_value)
  
  # take the difference 
  iterations_rdn = sample(unique(tmpt0$iterations))
  tmpt0[, iterations := iterations_rdn, by = "age_index"]
  tmp = merge(tmpt, tmpt0, by = c("iterations", "age_index"))
  tmp[, difference :=value_t - value_t0]
  
  # summarise
  tmp = tmp[, list( 	q= quantile(difference, prob=ps),
                     q_label=p_labs), 
            by=c('age_index')]		
  tmp = dcast(tmp, age_index ~ q_label, value.var = "q")
  
  return(select(tmp, all_of(p_labs), age_index))
}

find_diff_cases_monthly = function(fit_monthly_t, fit_monthly_t0, name_var, abbr_variable, df_age_strata, path.to.ifr.by.age, add_2049 = 0){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- paste0(c('M','CL','CU'), "_",abbr_variable)
  
  # if empty
  if(is.null(fit_monthly_t) | is.null(fit_monthly_t0)){
    tmp2 = data.table(age_index = df_age_strata$age_index, `M` = NA, `CL` = NA, `CU` = NA)
    colnames(tmp2)[2:4] = p_labs
    return(tmp2)
  }
  
  # extract samples
  fit_samples_t = rstan::extract(fit_monthly_t)
  fit_samples_t0 = rstan::extract(fit_monthly_t0)
  
  # aggregate ifr by age
  ifr.by.age = as.data.table( read.csv(path.to.ifr.by.age) )
  df = unique(select(df_age_strata, age_from, age_to, age_index))
  df = df[order(age_from)]
  max.age = max(ifr.by.age$age)
  ifr.by.age.agg = vector(mode = "list", length = nrow(df))
  for(i in 1:nrow(df)){
    ifr.by.age.agg[[i]] = ifr.by.age[ age >= df$age_from[i] & age <= min(df$age_to[i], max.age), -1][,list( ifr_mean = mean(ifr_mean))]
    ifr.by.age.agg[[i]]$age_index = df$age_index[i]
  }
  ifr.by.age.agg = do.call("rbind", ifr.by.age.agg)
  
  # proportion of death predicted at time t
  tmpt = as.data.table( reshape2::melt(fit_samples_t[[name_var]]) )
  colnames(tmpt) = c("iterations", "age_index",  "value_t")
  tmpt = merge(tmpt, ifr.by.age.agg, by = "age_index")
  if(add_2049){
    tmp1 = subset(tmpt, age_index %in% 3:4)
    tmp1 = tmp1[, list(value_t = sum(value_t), ifr_mean = mean(ifr.by.age[age >= 20 & age <= 49]$ifr_mean), age_index = 0), by = c("iterations")]
    tmpt = rbind(tmpt, tmp1 )
  }
  tmpt[, value_t := value_t / ifr_mean]
  tmp1 = tmpt[age_index != 0, list(n_value = sum(value_t)) , by = c("iterations") ]
  tmpt = merge(tmpt, tmp1,  by = c("iterations") )
  tmpt[, value_t := value_t / n_value]
  tmpt = select(tmpt, -n_value)
  
  # proportion of death predicted at time 0
  tmpt0 = as.data.table( reshape2::melt(fit_samples_t0[[name_var]]) )
  colnames(tmpt0) = c("iterations", "age_index",  "value_t0")
  tmpt0 = merge(tmpt0, ifr.by.age.agg, by = "age_index")
  if(add_2049){
    tmp1 = subset(tmpt0, age_index %in% 3:4)
    tmp1 = tmp1[, list(value_t0 = sum(value_t0), ifr_mean = mean(ifr.by.age[age >= 20 & age <= 49]$ifr_mean), age_index = 0), by = c("iterations")]
    tmpt0 = rbind(tmpt0, tmp1 )
  }
  tmpt0[, value_t0 := value_t0 / ifr_mean]
  tmp1 = tmpt0[age_index != 0, list(n_value = sum(value_t0)) , by = c("iterations") ]
  tmpt0 = merge(tmpt0, tmp1,  by = c("iterations") )
  tmpt0[, value_t0 := value_t0 / n_value]
  tmpt0 = select(tmpt0, -n_value)
  
  # take the difference 
  iterations_rdn = sample(unique(tmpt0$iterations))
  tmpt0[, iterations := iterations_rdn, by = "age_index"]
  tmp = merge(tmpt, tmpt0, by = c("iterations", "age_index"))
  tmp[, difference :=value_t - value_t0]
  
  # summarise
  tmp = tmp[, list( 	q= quantile(difference, prob=ps),
                     q_label=p_labs), 
            by=c('age_index')]		
  tmp = dcast(tmp, age_index ~ q_label, value.var = "q")
  
  return(select(tmp, all_of(p_labs), age_index))
}



make_convergence_diagnostics_stats = function(fit, no_fit){
  
  if(no_fit) return(0)
  
  summary = rstan::summary(fit_cum)$summary
  eff_sample_size_cum[[j]] <<- summary[,9][!is.na(summary[,9])]
  Rhat_cum[[j]] <<- summary[,10][!is.na(summary[,10])]
  cat("the minimum and maximum effective sample size are ", range(eff_sample_size_cum[[j]]), "\n")
  cat("the minimum and maximum Rhat are ", range(Rhat_cum[[j]]), "\n")
  stopifnot(min(eff_sample_size_cum[[j]]) > 500)
}

make_convergence_diagnostics_plots = function(fit, title, suffix, no_fit){
  
  if(no_fit) return(0)
  
  posterior <- as.array(fit)
  p_trace = bayesplot::mcmc_trace(posterior, regex_pars = c("beta", "v_inflation")) + labs(title = title)
  p_pairs = gridExtra::arrangeGrob(bayesplot::mcmc_pairs(posterior, regex_pars = c("beta", "v_inflation")), top = title)
  p_intervals = bayesplot::mcmc_intervals(posterior, regex_pars = c("beta", "v_inflation")) + labs(title = title)
  
  ggsave(p_trace, file = file.path(outdir.fig, "convergence_diagnostics", paste0("trace_plots_", suffix, '_', Code, "_", Date, "_", run_tag,".png") ), w= 8, h = 8)
  ggsave(p_pairs, file = file.path(outdir.fig, "convergence_diagnostics", paste0("pairs_plots_",  suffix, '_',Code, "_", Date, "_", run_tag,".png") ), w= 8, h = 10)
  ggsave(p_intervals, file = file.path(outdir.fig, "convergence_diagnostics", paste0("intervals_plots_",  suffix, '_',Code, "_", Date, "_", run_tag,".png") ), w= 8, h = 8)
  
}










