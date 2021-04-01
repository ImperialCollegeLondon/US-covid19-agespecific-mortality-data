compare_CDC_JHU_error_plot = function(CDC_data, JHU_data, var.cum.deaths.CDC, outdir)
{
  # find errors 
  JHUData = select(as.data.table(JHUData), code, date, cumulative_deaths)
  CDCdata = CDC_data[, list(cumulative_deaths.CDC = sum(na.omit( get(var.cum.deaths.CDC) ))), by = c('code', 'date')]
  CDCdata = subset(CDCdata, cumulative_deaths.CDC > 0)
  tmp1 = merge(JHUData, CDCdata, by = c('code', 'date'))
  tmp1[, prop_diff := abs(cumulative_deaths - cumulative_deaths.CDC) / cumulative_deaths ]
  tmp1 = tmp1[, list(prop_diff = sum(prop_diff) / length(date)), by = c('code') ]
  
  # plot
  JHUData[, source := 'JHU']
  CDCdata[, source := 'CDC']
  setnames(CDCdata, 'cumulative_deaths.CDC', 'cumulative_deaths')
  
  tmp2 = rbind(JHUData, CDCdata)
  tmp2 = merge(tmp2, tmp1, by = 'code')
  tmp2[, code_2 := paste0(code, ', ', round(prop_diff*100, digits = 2), ' % error')]
  
  p = ggplot(tmp2, aes(x = date, y = cumulative_deaths, col = source)) + 
    geom_line() +
    facet_wrap(~code_2, nrow = length(unique(tmp1$code)), scale = 'free') + 
    theme_bw() + 
    scale_color_viridis_d(option = "B", direction = -1, end = 0.8) 
  ggsave(p, file = paste0(outdir, '-comparison_JHU_CDC.png'), w = 9, h = 110, limitsize = F)
}

