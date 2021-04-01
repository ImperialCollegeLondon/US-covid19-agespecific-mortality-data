plot_continuous_age_contribution = function(fit, df_age_continuous, df_week, lab, outdir){
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- c('M','CL','CU')
  
  if(is.null(fit)) return(ggplot())
  
  # extract samples
  fit_samples = rstan::extract(fit)
  
  tmp1 = as.data.table( reshape2::melt(fit_samples$phi) )
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
  
  ggsave(p, file = paste0(outdir, "-continuous_contribution_",Code, ".png") , w= 8, h = 6*n_row / 2, limitsize = FALSE)
  
}

make_convergence_diagnostics_plots = function(fit, title, suffix, outfile)
{
  
  stopifnot(!is.null(fit))
  
  posterior <- as.array(fit)
  
  pars = list("lambda", "nu", "rho", "sigma", "beta", "tau", c('aw', 'sd_aw'), c('sd_a_raw', 'a0_raw'), 'a_age', 'a0')

  for(j in 1:length(pars))
  {                     
    
    par = pars[[j]]
    
    if(any(!par %in% names(fit))) next
    
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


compare_CDC_JHU_error_plot_uncertainty = function(CDC_data, JHU_data, outdir)
{
  # prepare JHU data
  JHUData = select(as.data.table(JHUData), code, date, cumulative_deaths)
  JHUData[, CL_cumulative_deaths := NA]
  JHUData[, CU_cumulative_deaths := NA]
  
  # prepare  predicted CDC data
  CDCdata = CDC_data[, list(cumulative_deaths = sum( M_deaths_cum ),
                            CL_cumulative_deaths = sum( CL_deaths_cum ),
                            CU_cumulative_deaths = sum( CU_deaths_cum )), by = c('code', 'date')]
  
  # plot
  JHUData[, source := 'JHU']
  CDCdata[, source := 'CDC']
  
  tmp2 = rbind(JHUData, CDCdata)
  tmp2 = subset(tmp2, code %in% unique(CDCdata$code) & date <= max(CDCdata$date))
  
  p = ggplot(tmp2, aes(x = date, y = cumulative_deaths)) + 
    geom_ribbon(aes(ymin = CL_cumulative_deaths, ymax = CU_cumulative_deaths, fill = source), alpha = 0.5) +
    geom_line(aes(col = source), size = 1) +
    facet_wrap(~code, nrow = length(unique(tmp2$code)), scale = 'free') + 
    theme_bw() + 
    scale_color_viridis_d(option = "B", direction = -1, end = 0.8) + 
    scale_fill_viridis_d(option = "B", direction = -1, end = 0.8)
  ggsave(p, file = paste0(outdir, '-comparison_JHU_CDC_uncertainty.png'), w = 9, h = 110, limitsize = F)
}

