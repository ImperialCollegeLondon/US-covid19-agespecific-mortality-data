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

plot_estimated_cov_matrix = function()
{
  samples = extract(fit_cum)
  
  suffix = '_ICAR'
  
  D = diag( apply(stan_data$Adj, 2, sum) )
  tau_m = median(samples$tau)
  p_m = median(samples$p)
  cov_m = tau_m * solve(D - p_m * stan_data$Adj)
  
  tmp1 = as.data.table( reshape2::melt( stan_data$Adj ))
  ggplot(tmp1, aes(x = Var1, y = Var2)) + 
    geom_raster(aes(fill = as.factor(value)))+
    scale_fill_manual(values = c('beige',"blue")) + 
    labs(x = expression(s[j]), y = expression(s[i]), fill = '') + 
    scale_y_reverse(expand = c(0,0))  +
    scale_x_continuous(expand = c(0,0)) +
    theme(legend.position = 'none')
  ggsave(file = '~/Box\ Sync/2021/CDC/beta_Adj.png', w = 4, h = 4)
  
  tmp1 = as.data.table( reshape2::melt( D ))
  ggplot(tmp1, aes(x = Var1, y = Var2)) + 
    geom_raster(aes(fill = value)) +
    labs(x = expression(s[j]), y = expression(s[i]), fill = '') + 
    scale_y_reverse(expand = c(0,0))  +
    scale_x_continuous(expand = c(0,0)) +
    theme(legend.position = 'none') + 
    scale_fill_viridis_c() 
  ggsave(file = '~/Box\ Sync/2021/CDC/beta_D.png', w = 4, h = 4)
  
  tmp1 = as.data.table( reshape2::melt( cov_m ))
  range_value = range(tmp1$value)
  ggplot(tmp1, aes(x = Var1, y = Var2)) + 
    geom_raster(aes(fill = value)) +
    labs(x = expression(s[j]), y = expression(s[i]), fill = 'Estimated posterior value') + 
    scale_y_reverse(expand = c(0,0))  +
    scale_x_continuous(expand = c(0,0)) +
    theme(legend.position = 'none') + 
    scale_fill_viridis_c(begin = 0, end = 1, limits = range_value, breaks = seq(0,0.6,0.2)) 
  ggsave(file = paste0('~/Box\ Sync/2021/CDC/beta_cov', suffix, '.png'), w = 4, h = 4)
  
  map = data.table(idx = 1:(stan_data$W * stan_data$num_basis), 
                   idx_week = rep(1:stan_data$W, each = stan_data$num_basis),
                   idx_basis = rep(1:stan_data$num_basis, stan_data$W))
  tmp1 = merge(tmp1, map, by.x = 'Var1', by.y = 'idx')
  setnames(tmp1, c('idx_week', 'idx_basis'), c('idx_week_column', 'idx_basis_column'))
  tmp1 = merge(tmp1, map, by.x = 'Var2', by.y = 'idx')
  setnames(tmp1, c('idx_week', 'idx_basis'), c('idx_week_row', 'idx_basis_row'))
  
  tmp2 = subset(tmp1, idx_week_row %in% 1 & idx_week_column %in% 1)
  ggplot(tmp2, aes(x = Var1, y = Var2)) + 
    geom_raster(aes(fill = value)) +
    labs(x = 'basis function index', y = 'basis function index', fill = 'Estimated posterior value') + 
    scale_y_reverse(expand = c(0,0), breaks = seq(1, 10, 2))  +
    scale_x_continuous(expand = c(0,0), breaks = seq(1, 10, 2)) +
    theme(legend.position = 'none') + 
    scale_fill_viridis_c(begin = 0, end = 1, limits = range_value, breaks = seq(0,0.6,0.2)) 
  ggsave(file = paste0('~/Box\ Sync/2021/CDC/beta_cov_w1', suffix, '.png'), w = 4, h = 4)
  
  tmp2 = subset(tmp1, idx_basis_column %in% 5 & idx_basis_row %in% 5)
  ggplot(tmp2, aes(x = idx_week_row, y = idx_week_column)) + 
    geom_raster(aes(fill = value)) +
    labs(x = 'week index', y = 'week index', fill = 'Estimated posterior value') + 
    scale_y_reverse(expand = c(0,0))  +
    scale_x_continuous(expand = c(0,0)) +
    theme(legend.position = 'none') + 
    scale_fill_viridis_c(begin = 0, end = 1, limits = range_value, breaks = seq(0,0.6,0.2)) 
  ggsave(file = paste0('~/Box\ Sync/2021/CDC/beta_cov_k5', suffix, '.png'), w = 4, h = 4)
  
}

plot_beta_posterior_plane = function()
{
  samples = extract(fit_cum)
  
  row_name = 'week_index'
  column_name = 'age'
  
  suffix = '_ICAR_2'
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- c('M','CL','CU')
  tmp1 = as.data.table( reshape2::melt( samples$beta ))
  setnames(tmp1, c('Var2', 'Var3'), c(row_name, column_name))
  tmp1 = tmp1[, list( 	q= quantile(value, prob=ps),
                       q_label=p_labs), 
              by=c(column_name, row_name)]	
  tmp1 = dcast(tmp1, get(row_name) + get(column_name) ~ q_label, value.var = "q")
  setnames(tmp1, c('row_name', 'column_name'), c(row_name, column_name))
  
  tmp1 = merge(tmp1, df_week, by = row_name)

  ggplot(tmp1, aes(x = date, y = get(column_name))) +
    geom_raster(aes(fill = M))  + 
    labs(x = 'Date', y = column_name, fill = 'Estimated posterior value') + 
    scale_y_reverse(expand = c(0,0))  +
    scale_x_date(expand = c(0,0)) + 
    scale_fill_viridis_c(option = "A") + 
    theme(legend.position='bottom')
  ggsave(file = paste0('~/Box\ Sync/2021/CDC/beta_posterior', suffix, '.png'), w = 6, h = 6.5)
  
}

plot_prediction = function()
{
  source(file.path(indir, "CDC-covid-tracker", "functions", "CDC-covid-tracker-postprocessing-summary_functions.R"))
  
  suffix = '_ICAR_2'
  
  predictive_checks_table = make_predictive_checks_table(fit_cum, "deaths_cum", df_week, df_age_reporting, tmp)
  
  tmp = subset(predictive_checks_table, week_index %in% c(1, stan_data$W))
  
  ggplot(tmp, aes(x = age)) + 
    geom_point(aes(y = M_deaths_cum)) + 
    geom_errorbar(aes(ymin = CL_deaths_cum, ymax = CU_deaths_cum)) + 
    geom_point(aes(y = COVID.19.Deaths), col = 'red') + 
    facet_wrap(~date, ncol = 1) + 
    theme_bw() + 
    labs(y = 'Cumulative deaths', x = '')
  ggsave(file = paste0('~/Box\ Sync/2021/CDC/posterior_predictive_checks_AL', suffix, '.png'), w = 6, h = 5)
}

plot_contribution = function()
{
  samples = extract(fit_cum)
  
  suffix = '_ICAR_2'
  
  ps <- c(0.5, 0.025, 0.975)
  p_labs <- c('M','CL','CU')
  tmp1 = as.data.table( reshape2::melt( samples$phi ))
  setnames(tmp1, c('Var2', 'Var3'), c('age', 'week_index'))
  tmp1 = tmp1[, list( 	q= quantile(value, prob=ps),
                       q_label=p_labs), 
              by=c('age', 'week_index')]	
  tmp1 = dcast(tmp1, week_index + age ~ q_label, value.var = "q")

  tmp1 = merge(tmp1, df_week, by = row_name)
  
  ggplot(tmp1, aes(x = date, y = age)) +
    geom_raster(aes(fill = M))  + 
    labs(x = 'Date', y = 'Age', fill = 'Estimated posterior value') + 
    scale_y_continuous(expand = c(0,0))  +
    scale_x_date(expand = c(0,0)) + 
    scale_fill_viridis_c(option = "E") + 
    theme(legend.position='bottom')
  ggsave(file = paste0('~/Box\ Sync/2021/CDC/continuous_contribution_AL_all_week', suffix, '.png'), w = 6, h = 6.2)
  
  tmp1 = subset(tmp1, week_index %in% c(1, stan_data$W))
  
  ggplot(tmp1, aes(x = age)) + 
    geom_line(aes(y = M)) + 
    geom_ribbon(aes(ymin = CL, ymax = CU), alpha  = 0.5) + 
    facet_wrap(~date, ncol = 1) + 
    theme_bw() + 
    labs(y = 'Probability that one additional deaths \n falls in a', x = 'a')
  ggsave(file = paste0('~/Box\ Sync/2021/CDC/continuous_contribution_AL', suffix, '.png'), w = 6, h = 5)
  
}