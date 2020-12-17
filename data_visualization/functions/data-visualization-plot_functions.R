library(usmap)
library(ggplot2)
library(maps)
library("rgdal")
library(viridis)
library(grid)
library(scales)
library(ggpubr)
library(directlabels)
library(gridExtra)
library(DescTools)
library(ggrepel)

`%notin%` = Negate(`%in%`)
  
plot_cum_deaths_by_age = function(deathByAge, selected_states){
  
  # all cum deaths
  deathByAge2 = copy(deathByAge)
  deathByAge2[, age_cat_from:= as.integer(gsub('\\+','',gsub('^([0-9]+)-([0-9]+)','\\1',age)))]
  
  #	remove rows with no deaths
  deathByAge3 <- subset(deathByAge, cum.deaths>0)
  
  #	calculate number of stacked deaths up to age band a
  deathByAge3[, age_cat_from:= as.integer(gsub('\\+','',gsub('^([0-9]+)-([0-9]+)','\\1',age)))]
  setkey(deathByAge3, code, date, age_cat_from)
  tmp <- deathByAge3[, list( 	age_cat_from=age_cat_from,
                             cum.deaths.stacked=cumsum(cum.deaths),
                             cum.deaths.stacked.before=c(0, cumsum(cum.deaths[-length(cum.deaths)]))
  ), by=c('code','date')]
  #	calculate corresponding proportion of stacked deaths up to age band a					
  tmp <- tmp[, list(	date=date,
                     age_cat_from=age_cat_from, 
                     cum.deaths.stacked=cum.deaths.stacked,
                     cum.deaths.stacked.p= cum.deaths.stacked/max(cum.deaths.stacked),
                     cum.deaths.stacked.before=cum.deaths.stacked.before,
                     cum.deaths.stacked.before.p= cum.deaths.stacked.before/max(cum.deaths.stacked)
  ), by='code']					
  
  deathByAge3 <- merge(deathByAge3,tmp,by=c('code','date','age_cat_from'))
  setkey(deathByAge3, code, date, age_cat_from)					
  
  # select four states
  deathByAge3 = subset(deathByAge3, code %in% selected_states)
  
  deathByAge.first.date <- deathByAge3[, min(date)]
  deathByAge.last.date <- deathByAge3[, max(date)]
  deathByAge.loc_labels <- unique(deathByAge3$loc_label)	
  
  dps_abs <- vector('list',length(deathByAge.loc_labels))
  dps_prop <- vector('list',length(deathByAge.loc_labels))
  for(i in seq_along(deathByAge.loc_labels) )
  {
    tmp <- subset(deathByAge2, loc_label==deathByAge.loc_labels[i])[order(age_cat_from),]

    dps_abs[[i]] <- ggplot(tmp, aes(x=date, y=cum.deaths, col=age)) +
      geom_line(size = 1) +
      coord_cartesian(xlim=c(deathByAge.first.date, deathByAge.last.date)) +				
      scale_x_date(expand=c(0,0), labels = date_format("%e %b")) +
      labs(x='', y='', color='Age band') +
      theme_bw() +
      ggtitle(tmp$loc_label[1]) +
      guides(color=guide_legend(ncol=1)) +
      theme(	plot.title = element_text(size=15, hjust = 0.5),
             #legend.position= 'bottom',
             legend.position= c(0.3,0.55),
             #legend.title=element_text(size=20),
             legend.text=element_text(size=rel(.7)),
             # text = element_text(size=20),
             legend.background=element_blank(),
             legend.key.size = unit(2, "mm"),
             axis.text.x = element_blank())
    
    tmp <- subset(deathByAge3, loc_label==deathByAge.loc_labels[i])[order(age_cat_from),]
    tmp[, age_cat_2:= factor(age_cat_from, levels=unique(tmp$age_cat_from), labels=unique(tmp$age) )]
    
    dps_prop[[i]] <- ggplot(tmp, aes(x=date, ymin=cum.deaths.stacked.before.p, ymax=cum.deaths.stacked.p, fill=age_cat_2)) +
      coord_cartesian(xlim=c(deathByAge.first.date, deathByAge.last.date), ylim=c(0,1)) +				
      geom_ribbon(alpha = 0.8) +
      geom_line(aes(y=cum.deaths.stacked.p), show.legend = FALSE, size = 0.5, alpha =0.5, color = "lightgrey") +
      scale_x_date(expand=c(0,0), labels = date_format("%e %b")) +
      scale_y_continuous(labels=scales:::percent, expand=c(0,0)) +
      labs(x='', y='', fill='Age band') +
      theme_bw() +
      guides(fill=guide_legend(ncol=1)) +
      theme(	plot.title = element_text(size=rel(1), hjust = 0.5),
             #legend.position= 'bottom',
             legend.position= c(0.3,0.55),
             #legend.title=element_text(size=20),
             legend.text=element_text(size=rel(.7)),
             # text = element_text(size=20),
             legend.background=element_blank(),
             legend.key.size = unit(2, "mm"),
             strip.text.x = element_blank(), 
             strip.background = element_blank(),
             axis.text.x = element_text(angle = 40, vjust = 0.5, hjust=1))
  }
  
  p1 <- gridExtra::grid.arrange(	grobs=dps_abs,
                                 ncol=4, 					
                                 left=text_grob('Reported COVID-19 \nmortality counts', size=15, rot = 90),
                                 widths = c(1, 1, 1, 1))
  
  p2 <- gridExtra::grid.arrange(	grobs=dps_prop,
                                 ncol=4, 					
                                 left=text_grob('Reported COVID-19 \nmortality counts in percent', size=15, rot = 90),
                                 widths = c(1, 1, 1, 1))
  
  p<- gridExtra::grid.arrange(p1, p2, nrow = 2)
  
  return(p)
}

plot_death_by_age_vs_deaths_overall <- function(deathByAge, death_data)
{
  
  #
  # Prepare death by age data
  # sum deaths by age over all age groups
  deathByAge_plot = deathByAge[, list(cum.deaths = sum(cum.deaths)), by = c("code", "loc_label", "date")]
  deathByAge_plot[, source := "Department of Health"]
  
  #
  # Prepare JHU and NYC data
  # find cumulative death
  death_data_plot = subset(death_data, code %in% unique(deathByAge$code)) 
  death_data_plot = death_data_plot[, list(cum.deaths = cumsum(daily_deaths),
                                           date = date), by = c("code", "loc_label")]
  death_data_plot[, source := "JHU or NYC GitHub Repository"]
  
  tmp = rbind(deathByAge_plot, death_data_plot) 
  tmp[, source := factor(source, levels = c("JHU or NYC GitHub Repository", "Department of Health"))]
  
  deathByAge.first.date <- min(tmp$date)
  deathByAge.last.date <- max(tmp$date)
  
  p <- ggplot(tmp, aes(x=date, y = cum.deaths, col = source)) +
    coord_cartesian(xlim=c(deathByAge.first.date, deathByAge.last.date)) +				
    geom_line() +
    #geom_point(size = 0.5) +
    scale_x_date(expand=c(0,0), labels = date_format("%e %b")) +
    labs(x='', y='COVID-19 mortality counts', colour='Source') +
    theme_bw() +
    facet_wrap(~loc_label, ncol = 5, scale = "free_y") +
    theme(	plot.title = element_text(size=rel(1), hjust = 0.5),
           #legend.position= 'bottom',
           legend.position= "bottom",
           #legend.title=element_text(size=20),
           legend.text=element_text(size=rel(1)),
           # text = element_text(size=20),
           legend.background=element_blank(),
           legend.key.size = unit(2, "mm"),
           axis.text.x = element_text(angle = 40, vjust = 0.5, hjust=1),
           panel.background = element_blank(), 
           strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" )) +
    scale_color_viridis_d(begin = 0, end = 0.8, option = "plasma")
  
  return(p)
}

plot_death_by_age_vs_deaths_overall_difference <- function(deathByAge, death_data)
{
  
  #
  # Prepare death by age data
  # sum deaths by age over all age groups
  deathByAge_plot = deathByAge[, list(cum.deaths_agestrat = sum(cum.deaths)), by = c("code", "loc_label", "date")]
  
  #
  # Prepare JHU and NYC data
  # find cumulative death
  death_data_plot = subset(death_data, code %in% unique(deathByAge$code)) 
  death_data_plot = death_data_plot[, list(cum.deaths_jhuorNYC = cumsum(daily_deaths),
                                           date = date), by = c("code", "loc_label")]
  
  tmp = merge(deathByAge_plot, death_data_plot, by = c("code", "loc_label", "date") )
  tmp1 = tmp[, list(last.cum.deatgs_jhuorNYC = max(cum.deaths_jhuorNYC)), by = "code"]
  tmp = merge(tmp, tmp1, by = "code")
  tmp[, diff := cum.deaths_agestrat - cum.deaths_jhuorNYC]
  tmp[diff!= 0, diff_scaled := diff/cum.deaths_jhuorNYC]
  tmp[diff== 0, diff_scaled := diff]
  tmp = subset(tmp, diff_scaled != Inf) # one obs for maine is 1 age-strat and 0 for JHU
  
  deathByAge.first.date <- min(tmp$date)
  deathByAge.last.date <- max(tmp$date)
  
  p = ggplot(tmp, aes(x=date, y = diff_scaled)) +
    coord_cartesian(xlim=c(deathByAge.first.date, deathByAge.last.date)) +
    geom_hline(yintercept = 0, col = "red", linetype = "dashed", alpha= 0.7) +				
    geom_line() +
    #geom_point(size = 0.5) +
    scale_x_date(expand=c(0,0), labels = date_format("%e %b")) +
    labs(x='', y="Proportional difference between the COVID-19 mortality counts reported \n by JHU/NYC GitHub repository and by the Department of Healths") +
    theme_bw() +
    facet_wrap(~loc_label, ncol = 5, scale = 'free_y') +
    scale_color_viridis_d(begin = 0, end = 0.8, option = "plasma") +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    #scale_y_continuous(limits = c(min(tmp$diff_scaled), max(tmp$diff_scaled))) + 
    theme(	plot.title = element_text(size=rel(1), hjust = 0.5),
           #legend.position= 'bottom',
           legend.position= "bottom",
           #legend.title=element_text(size=20),
           legend.text=element_text(size=rel(1)),
           # text = element_text(size=20),
           legend.background=element_blank(),
           legend.key.size = unit(2, "mm"),
           axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1),
           panel.background = element_blank(), 
           strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" )) 
  
  return(p)
}

plot_death_by_age_vs_deaths_overall_difference_rank <- function(deathByAge, death_data)
{
  
  #
  # Prepare death by age data
  # sum deaths by age over all age groups
  deathByAge_plot = deathByAge[, list(cum.deaths_agestrat = sum(cum.deaths)), by = c("code", "loc_label", "date")]

  #
  # Prepare JHU and NYC data
  # find cumulative death
  death_data_plot = subset(death_data, code %in% unique(deathByAge$code)) 
  death_data_plot = death_data_plot[, list(cum.deaths_jhuorNYC = cumsum(daily_deaths),
                                           date = date), by = c("code", "loc_label")]

  tmp = merge(deathByAge_plot, death_data_plot, by = c("code", "loc_label", "date") )
  tmp1 = tmp[, list(last.cum.deatgs_jhuorNYC = max(cum.deaths_jhuorNYC)), by = "code"]
  tmp = merge(tmp, tmp1, by = "code")
  tmp[, diff := cum.deaths_agestrat - cum.deaths_jhuorNYC]
  tmp[diff!= 0, diff_scaled := diff/cum.deaths_jhuorNYC]
  tmp[diff== 0, diff_scaled := diff]
  tmp = subset(tmp, diff_scaled != Inf) # one obs for maine is 1 age-strat and 0 for JHU
  
  # make categories
  tmp2 = tmp[, list(min_diff_scaled = min(diff_scaled),
                    max_diff_scaled = max(diff_scaled),
                    max_abs_diff_scaled = max(abs(diff_scaled))),  by = "code"]
  tmp2[, extr_diff_scaled := ifelse(abs(min_diff_scaled) == max_abs_diff_scaled, min_diff_scaled, max_diff_scaled)]
  tmp2 = tmp2[order(extr_diff_scaled)]
  n_category = 10
  tmp2[, category := c(rep(1:(n_category-1), each = ceiling(nrow(tmp2)/n_category)), rep(n_category, nrow(tmp2) - ceiling(nrow(tmp2)/n_category)*(n_category-1))) ]
  
  tmp = merge(tmp, select(tmp2, code, category), by = "code")
  
  deathByAge.first.date <- min(tmp$date)
  deathByAge.last.date <- max(tmp$date)
  
  p = vector(mode = "list", length = length(unique(tmp$category)))
  for(x in unique(tmp$category)){
    p[[x]] <- ggplot(subset(tmp, category == x), aes(x=date, y = diff_scaled)) +
      coord_cartesian(xlim=c(deathByAge.first.date, deathByAge.last.date)) +
      geom_hline(yintercept = 0, col = "red", linetype = "dashed", alpha= 0.7) +				
      geom_line() +
      #geom_point(size = 0.5) +
      scale_x_date(expand=c(0,0), labels = date_format("%e %b")) +
      labs(x='', y='') +
      theme_bw() +
      facet_wrap(~loc_label, ncol = 5) +
      scale_color_viridis_d(begin = 0, end = 0.8, option = "plasma") +
      scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
      #scale_y_continuous(limits = c(min(tmp$diff_scaled), max(tmp$diff_scaled))) + 
      theme(	plot.title = element_text(size=rel(1), hjust = 0.5),
             #legend.position= 'bottom',
             legend.position= "bottom",
             #legend.title=element_text(size=20),
             legend.text=element_text(size=rel(1)),
             # text = element_text(size=20),
             legend.background=element_blank(),
             legend.key.size = unit(2, "mm"),
             axis.text.x = element_text(angle = 40, vjust = 0.5, hjust=1),
             panel.background = element_blank(), 
             strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" )) 
    
    if(x != length(unique(tmp$category))){
      p[[x]] = p[[x]] + theme(axis.text.x = element_blank(), plot.margin=unit(c(5.5,5.5,-10,5.5), "pt"))
    }
    p[[x]] = gridExtra::grid.arrange(p[[x]])
  }
  
  #m = matrix(nrow = n_category, ncol = ceiling(nrow(tmp2)/n_category), rep(1:n_category, each = ceiling(nrow(tmp2)/n_category)), byrow = T)
  #m[n_category,] = c(rep(1, sum(tmp2$category == n_category)), rep(NA, ceiling(nrow(tmp2)/n_category) - sum(tmp2$category == n_category)))
  
  p1 = gridExtra::grid.arrange(grobs = p, nrow = n_category,
                               left = text_grob("Proportional difference between the COVID-19 mortality counts reported \n by JHU/NYC GitHub repository and by the Department of Healths", rot = 90),
                               heights = c(rep(0.65, length(unique(tmp$category)) - 1), 1) )
  
  return(p1)
}


plot_heat_map_usa = function(tmp, variable, xlab, option_viridis = "viridis", range_viridis = c(0, 1),scale_percent = 0,limits = NULL, main = NULL)
  {
  
  if(!'state' %in% colnames(tmp)) setnames(tmp, c("code"), c("state"))
  tmp = tmp[order(get(variable))]
  states = unique(tmp$state)
  
  cities_t <- usmap_transform(citypop)
  cities = subset(cities_t, most_populous_city %in% c("New York City"))
  
  if(is.null(limits)) limits = range(tmp[,get(variable)])
  
  scale_breaks = seq(floor(limits[1]), ceiling(limits[2]), length.out = 5)
  if(scale_percent) scale_label = scales::percent(scale_breaks)
  if(!scale_percent){
    if(sum(scale_breaks) > 10 & sum(scale_breaks) < 300) scale_breaks = RoundTo(scale_breaks, 5, floor)
    if(sum(scale_breaks) >= 300) scale_breaks = RoundTo(scale_breaks, 100)
    scale_label = scale_breaks
  }
    
  
  # US map
  p1 = plot_usmap(data = tmp, values = variable) +
    geom_segment(data = cities, aes(x = lon.1 - 5e5, y = lat.1 + 5e5, xend = lon.1 + 1e5, yend = lat.1 + 5e5), col = "black") + 
    geom_segment(data = cities, aes(x = lon.1+ 1e5, y = lat.1 + 5e5, xend = lon.1+ 1e5, yend = lat.1), col = "black") + 
    geom_segment(data = cities, aes(x = lon.1 - 5e5, y = lat.1 , xend = lon.1+ 1e5, yend = lat.1), col = "black") + 
    geom_segment(data = cities, aes(x = lon.1 - 5e5, y = lat.1 , xend = lon.1 - 5e5, yend = lat.1 + 5e5), col = "black") + 
    geom_segment(data = cities, aes(x = lon.1 + 1e5, y = lat.1 + 5e5/2, xend = lon.1 + 5e5, yend = lat.1 + 5e5/2), 
                 arrow = arrow(length = unit(0.2, "cm"), ends="last", type = "closed")) +
    scale_fill_viridis_c(name = xlab, option = option_viridis, begin = range_viridis[1], end = range_viridis[2], limits = limits,
                         labels = scale_label, breaks = scale_breaks) +
    theme(legend.position = c(0.9, 0), 
          plot.margin=unit(c(1,-0.6,-0.5,1), "cm"), 
          legend.text = element_text(size = 15), legend.title = element_text(size = 15)) 
  
  # Focus on New York
  a = (range_viridis[2] - range_viridis[1]) / ( limits[2] - limits[1] )
  b = range_viridis[1] - a * limits[1]
  begin = min(tmp[,get(variable)])*a + b; end = max(tmp[,get(variable)])*a + b
  
  color_palette = viridis(n = length(tmp[,get(variable)]), 
                          option = option_viridis, 
                          begin = begin, 
                          end = ifelse(end >1, 1, end))
  color_NYC = color_palette[which(states == c("NYC"))]
  p2 = plot_usmap(data = tmp, values = variable, include = c("NY", "CT", "MA", "VT"), labels = T) +
    ggrepel::geom_label_repel(data = cities, aes(x = lon.1 - 1e5, y = lat.1 + 2.5e4, label = most_populous_city),
                              force = 10, size = 2.5,
                              seed = 1000, fill = color_NYC) +
    geom_segment(data = cities, aes(xend = lon.1, y = lat.1, x = lon.1 - 1e5, yend = lat.1)) + 
    geom_segment(data = cities, aes(xend = lon.1, y = lat.1, x = lon.1 - 1e5, yend = lat.1), 
                 arrow = arrow(length = unit(0.2, "cm"), ends="last", type = "closed")) +
    theme(legend.position = "none", 
          plot.margin=unit(c(1,1,6.5,0), "cm"),
          panel.border = element_rect(colour = "black", fill=NA, size=1)) + 
    scale_fill_viridis_c(name = xlab, option = option_viridis, begin = range_viridis[1], end = range_viridis[2], limits = limits,
                         labels = scale_label) 
  
  g = gridExtra::grid.arrange(p1, p2, ncol = 2, widths = c(0.8, 0.35), 
                              top = text_grob(main, size=20, vjust = 2))
  
  return(g)
}


plot_death_per_100K_vs_time_since_10th_cum_death = function(death_summary)
  {
  
  death_summary[, loc_label := factor(loc_label, levels = unique(death_summary$loc_label)[order(unique(death_summary$loc_label), decreasing = F)])]
  
  # remove states with only one month observed 
  tmp = unique(select(death_summary, code, date))
  tmp = tmp[, list(N = length(date)), by = "code"]
  tmp1 = subset(death_summary, code %notin% tmp$code[which(tmp$N == 1)])
  tmp1[, age_label := paste0("ages \n",age)]
  
  locs = unique(tmp1$code); n_locs = length(locs)
  locs_list = list(`New \nEngland` = c("CT", "ME", "MA", "NH", "RI", "VT"),
                   `Middle \nAtlantic` = c("NJ", "NY", "PA", "NYC"),
                   `East North \nCentral` = c("IL", "IN", "MI", "OH", "WI"),
                   `West North \n Central` = c("IA", "KS", "MN", "MO", "NE", "ND", "SD"),
                   `South \nAtlantic 1` = c("DE", "DC", "FL", "GA", "MD"),
                   `South \nAtlantic 2` = c("NC", "SC", "VA", "WV"),
                   `South \nCentral` = c("AL", "KY", "MS", "TN", "AR", "LA", "OK", "TX"),
                   `\nMountain` = c("AZ", "CO", "ID", "MT", "NV", "NM", "UT", "WY"),
                   `\nPacific` = c("AK", "CA", "HI", "OR", "WA"))
  n = length(locs_list)

  limits_2549 = range(c(subset(tmp1, age == "25-49")$CL_deaths_cum_100K, subset(tmp1, age == "25-49")$CU_deaths_cum_100K))
  limits_5074 = range(c(subset(tmp1, age == "50-74")$CL_deaths_cum_100K, subset(tmp1, age == "50-74")$CU_deaths_cum_100K))
  limits_75p = range(c(subset(tmp1, age == "75+")$CL_deaths_cum_100K, subset(tmp1, age == "75+")$CU_deaths_cum_100K))
  
  p = vector(mode = "list", length = n)
  for(i in 1:n){
    
    data = subset(tmp1, code %in% locs_list[[i]] & age == "25-49")
    p2549 = ggplot(data, aes(x = as.numeric(time_since_nth_cum_deaths))) +
      geom_line(aes(y = M_deaths_cum_100K, col = loc_label)) + 
      geom_ribbon(aes(ymin = CL_deaths_cum_100K, ymax = CU_deaths_cum_100K, fill = loc_label), alpha = 0.2) +
      theme_bw() +
      ggtitle(names(locs_list[i])) +
      scale_y_continuous(limits = limits_2549) +
      scale_x_continuous(limits = c(0,as.numeric(max(tmp1$time_since_nth_cum_deaths)))) + 
      labs(col = "Location", fill = 'Location') + 
      theme(plot.title = element_text(hjust = 0.5), legend.position = "bottom",
            axis.title.x = element_blank(), axis.title.y = element_blank(), axis.text.x =element_blank()) +
      ggrepel::geom_text_repel(data = subset(data, date == max(data$date)),
                               aes(label = code, y = M_deaths_cum_100K, col = loc_label),
                               size = 4, segment.alpha = 0.1, segment.color = "gray72", segment.size = 0.1)
    
    data = subset(tmp1, code %in% locs_list[[i]] & age == "50-74")
    p5074 = ggplot(data, aes(x = as.numeric(time_since_nth_cum_deaths))) +
      geom_line(aes(y = M_deaths_cum_100K, col = loc_label)) + 
      geom_ribbon(aes(ymin = CL_deaths_cum_100K, ymax = CU_deaths_cum_100K, fill = loc_label), alpha = 0.2) + 
      scale_x_continuous(limits = c(0,as.numeric(max(tmp1$time_since_nth_cum_deaths)))) + 
      theme_bw() +
      scale_y_continuous(limits = limits_5074) + 
      theme(axis.title.x = element_blank(), axis.title.y = element_blank(), axis.text.x =element_blank()) +
      ggrepel::geom_text_repel(data = subset(data, date == max(data$date)),
                      aes(label = code, y = M_deaths_cum_100K, col = loc_label),
                      size = 4, segment.alpha = 0.5, segment.color = "gray72", segment.size = 0.1)
    
    data = subset(tmp1, code %in% locs_list[[i]] & age == "75+")
    p75p = ggplot(data, aes(x = as.numeric(time_since_nth_cum_deaths))) +
      geom_line(aes(y = M_deaths_cum_100K, col = loc_label)) +
      geom_ribbon(aes(ymin = CL_deaths_cum_100K, ymax = CU_deaths_cum_100K, fill = loc_label), alpha = 0.2) + 
      scale_x_continuous(limits = c(0,as.numeric(max(tmp1$time_since_nth_cum_deaths)))) + 
      scale_y_continuous(limits = limits_75p) +
      theme_bw()  + 
      theme(axis.title.x = element_blank(), axis.title.y = element_blank()) +
      ggrepel::geom_text_repel(data = subset(data, date == max(data$date)),
                      aes(label = code, y = M_deaths_cum_100K, col = loc_label),
                      size = 4, segment.alpha = 0.5, segment.color = "gray72", segment.size = 0.1) # box.padding = unit(0.35, "dotted lines"), point.padding = unit(0.3, "dotted lines")
      
    if(i == 1){
      p2549 = p2549 + theme(plot.margin=unit(c(5.5, 5.5, 5.5, 13), "pt"))
      p5074 = p5074 + theme(plot.margin=unit(c(5.5, 5.5, 5.5, 10), "pt"))
    }
    if(i != 1){
      p2549 = p2549 + theme(axis.text.y =element_blank())
      p5074 = p5074 + theme(axis.text.y =element_blank())
      p75p = p75p + theme(axis.text.y =element_blank())
    }
    if(i == n){
      p2549 = p2549 + facet_grid(age_label~.) + 
        theme(strip.text.y = element_text(size = 13), panel.background = element_blank(),
              strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" ))
      p5074 = p5074 + facet_grid(age_label~.)  + 
        theme(strip.text.y = element_text(size = 13), panel.background = element_blank(),
              strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" ))
      p75p = p75p + facet_grid(age_label~.)  + 
        theme(strip.text.y = element_text(size = 13), panel.background = element_blank(),
              strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" ))
    } 
    
    
    p[[i]] = ggpubr::ggarrange(p2549, p5074, p75p, nrow = 3, 
                               legend = "none",
                               heights = c(1, rep(0.95, 2))) 

  }
  
  grid.newpage()
  p1 = gridExtra::grid.arrange( grobs = p, ncol = n, 
                                bottom = text_grob("Days since 10th COVID-19 mortality count", size = 15), 
                                left = text_grob("COVID-19 mortality counts per 100,000 individuals", rot = 90, size = 15),
                                widths = c(1.1, rep(0.9, n-2), 1.2))

  return(p1)
}

plot_mortality_rate = function(mortality_rate_by_age, trans){
  
  tmp = subset(mortality_rate_by_age, !is.na(cum.deaths))
  tmp = subset(tmp, loc_label != "All locations")
  tmp[, loc_label := factor(loc_label, levels = unique(tmp$loc_label)[order(unique(tmp$loc_label), decreasing = T)])]
  
  p = ggplot(tmp, aes(x = date, y = loc_label)) + 
    geom_raster(aes(fill = mortality_rate)) +
    facet_wrap(~age_cat, ncol = 4)+
    theme_bw() +
    labs(y = "", x = "", fill = "Mortality Rate") +
    geom_hline(yintercept = 1:length(unique(tmp$loc_label))+0.5, col = "gray78") +
    theme(legend.position="bottom",
          legend.title = element_text(size = 16), 
          legend.text = element_text(size = 14),
          axis.text.x=element_text(size=14, angle = 70, hjust = 1),
          axis.text.y=element_text(size=14),
          axis.title=element_text(size=20),
          strip.text = element_text(size = 16),
          strip.background = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          panel.background = element_blank(),
          panel.spacing = unit(1, "lines")) +
    scale_x_date(date_breaks = "2 weeks", labels = date_format("%e %b"), expand=c(0.01,0)) +
    guides(fill = guide_colourbar(barwidth = 15, barheight = 0.5,direction="horizontal")) + 
    scale_fill_viridis(option = "magma", begin = 0.2, end = 1, trans = trans) 
  
  return(p)
}

plot_proportion_absolute_cum_death_by_age = function(tmp){
  
  divisions = c("New \nEngland", "Middle \nAtlantic", "East North \nCentral", "West North \nCentral", 
                "South \nAtlantic", "South \nCentral", "Mountain", "Pacific")
  
  # break line for some of the division for space
  tmp[division == "New England", division := "New \nEngland"]
  tmp[division == "Middle Atlantic", division := "Middle \nAtlantic"]
  tmp[division == "East North Central", division := "East North \nCentral"]
  tmp[division == "West North Central", division := "West North \nCentral"]
  tmp[division == "South Atlantic", division := "South \nAtlantic"]
  tmp[division == "South Central", division := "South \nCentral"]

  # prepare tmp
  tmp[, age := factor(age, levels = c(unique(tmp$age)))]
  tmp[, loc_label := factor(loc_label, levels = rev(sort(unique(tmp$loc_label))))]
  tmp[, division := factor(division, levels = divisions) ]
  
  p1 = ggplot(tmp, aes(x = loc_label, y = M_deaths_cum, fill = age)) + 
    geom_bar(stat = "identity", position = position_stack(reverse = TRUE)) + 
    labs(x = "", y = "COVID-19 mortality counts", fill = "Age band") +
    scale_fill_viridis_d(option = "inferno", begin = 0.1, end = 0.8) + 
    scale_y_continuous(expand = c(0,0)) + 
    coord_flip()  + 
    facet_grid(division~., scales = "free", switch = "x", space = "free") + 
    theme_light() +
    theme(legend.position = "bottom", 
          panel.spacing = unit(0.1, "lines"),  
          strip.background = element_blank(), 
          strip.text = element_blank()) 
  p2 = ggplot(tmp, aes(x = loc_label, y = M_deaths_prop_cum, fill = age)) + 
    geom_bar(stat = "identity", position = position_fill(reverse = TRUE)) + 
    labs(x = "", y = "Proportion of COVID-19 mortality counts by age band", fill = "Age band") +
    scale_fill_viridis_d(option = "inferno", begin = 0.1, end = 0.8) + 
    scale_y_continuous(expand = c(0,0), labels = scales::percent) + 
    coord_flip()  + 
    facet_grid(division~., scales = "free", switch = "x", space = "free") + 
    theme_light()+
    theme(legend.position = "bottom", 
          panel.spacing = unit(0.1, "lines"),  
          strip.background = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          panel.background = element_blank(), 
          axis.text.y = element_blank(),
          strip.text = element_text(colour = 'black')) 
  
  p = ggarrange(p1, p2, ncol = 2, common.legend = T, legend = "bottom", widths = c(1.35, 1.15))
  
  return(p)
}

plot_death_per_100K = function(tmp){
  divisions = c("New \nEngland", "Middle \nAtlantic", "East North \nCentral", "West North \nCentral", 
                "South \nAtlantic", "South \nCentral", "Mountain", "Pacific")
  
  # break line for some of the division for space
  tmp[division == "New England", division := "New \nEngland"]
  tmp[division == "Middle Atlantic", division := "Middle \nAtlantic"]
  tmp[division == "East North Central", division := "East North \nCentral"]
  tmp[division == "West North Central", division := "West North \nCentral"]
  tmp[division == "South Atlantic", division := "South \nAtlantic"]
  tmp[division == "South Central", division := "South \nCentral"]
  
  # prepare tmp
  tmp[, age := factor(age, levels = c(unique(tmp$age)))]
  tmp[, loc_label := factor(loc_label, levels = rev(sort(unique(tmp$loc_label))))]
  tmp[, division := factor(division, levels = divisions) ]
  
  tmp1 = subset(tmp, age != "0-24")
  p = ggplot(tmp1, aes(x = loc_label, y = M_deaths_cum_100K)) + 
    facet_grid(age~division, scales = "free", space = "free_x") + 
    geom_bar(aes(fill = M_deaths_cum_100K), stat = "identity") + 
    geom_errorbar(aes(ymin = CL_deaths_cum_100K, ymax = CU_deaths_cum_100K), alpha = 0.7, width = 0.4) + 
    theme_light() + 
    theme( legend.position = "none",
           axis.text.x = element_text(angle = 90, hjust = .5),
           panel.spacing = unit(0.1, "lines"),  
           strip.background = element_blank(),
           panel.background = element_blank(), 
           strip.text = element_text(colour = 'black')) + 
    labs(x = "", y = "COVID-19 mortality counts per 100,000 individuals") +
    scale_fill_gradient(low = "blue", high = "red")
  
  return(p)
  
}

plot_predicted_observed_deaths = function(tmp, variable, lab){
  
  tmp[, loc_label := factor(loc_label, levels = unique(tmp$loc_label)[order(unique(tmp$loc_label), decreasing = F)])]
  tmp[, date_label := format(date, "%B %d, %Y")]
  tmp[, date_label := factor(date_label, levels = format(sort(unique(tmp$date)), "%B %d, %Y") )]
  
  p1 = ggplot(tmp, aes(x = get(variable), y = M_deaths_cum)) +
    geom_abline(slope = 1, linetype = "dashed", alpha = 0.5) +
    geom_point(aes(col = loc_label)) +
    geom_errorbar(aes(ymin = CL_deaths_cum, ymax = CU_deaths_cum), width = .2, alpha = 0.5, col = "black") +
    theme_bw() +
    labs(y = paste0("Predicted ", lab), x = paste0("Observed ", lab), col = "") +
    facet_wrap(~date_label, ncol = 3, scales ="free") +
    theme(legend.position = "bottom",
          panel.background = element_blank(), strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" ))+
    guides(col = guide_legend(nrow = 6)) 
  
  
  return(p1)
}

plot_proportion_monthly_death_by_age <- function(tmp, alpha_bar, with_viridis)
{
  
  tmp = subset(tmp, !is.na(M_deaths_prop_monthly))
  
  # find states which have a significant change in the proportion of the oldest age bandfrom the first month with cum death > 30
  for(m in seq_along(unique(tmp$code))){
    Age_oldest = unique(tmp$age)[length( unique(tmp$age))]
    tmp1 = subset(tmp, code == unique(tmp$code)[m] & age == Age_oldest)
    
    tmp1[, dummy := F]
    tmp1[, dummy := CL_diff_deaths_monthly < 0 & CU_diff_deaths_monthly < 0]
    tmp1[dummy == F, dummy := CL_diff_deaths_monthly > 0 & CU_diff_deaths_monthly > 0]
    if(any(na.omit(tmp1$dummy))) tmp[code == unique(tmp$code)[m], loc_label := paste0(loc_label, "*")]
  }
  
  # fnd national average
  national_avg = tmp[, list(M_deaths_prop_monthly_avg = mean(na.omit(M_deaths_prop_monthly))), by = c("month", "age", "age_from")]
  national_avg[order(month, age_from, decreasing = T), M_deaths_prop_monthly_cumsum_avg := cumsum(M_deaths_prop_monthly_avg), by = "month"]
  national_avg75 = subset(national_avg, age == "75+")
  tmp = merge(tmp, national_avg75, by = c("month", "age", "age_from"), all.x = T)
  
  # plot
  deathByAge.first.date <- tmp[, min(date)]
  deathByAge.last.date <- tmp[, max(date)]
  
  p = ggplot(tmp, aes(x=date)) +
    geom_bar(aes(y=M_deaths_prop_monthly, fill=age), stat='identity',position='fill', alpha = alpha_bar, width = 1) +
    geom_line(aes(y = M_deaths_prop_monthly_cumsum_avg, group = age), size = 1, col = "gray34") + 
    labs(x='', y='Proportion of COVID-19 monthly deaths', fill='Age band', col = 'Age band') +
    scale_x_date(expand=c(0,0),date_breaks = "2 months", labels = date_format("%e %b")) +
    coord_cartesian(xlim=c(deathByAge.first.date, deathByAge.last.date), ylim=c(0,1))  +
    theme_bw(base_size=22) + 
    facet_wrap(~loc_label, ncol = 5) +
    theme(legend.position= 'bottom',
          legend.title=element_text(size=rel(.9)),
          legend.text=element_text(size=rel(.9)),
          # text = element_text(size=20),
          legend.background=element_blank(),
          legend.key.size = unit(2, "mm"),
          panel.grid.major = element_blank() ,
          panel.grid.minor = element_blank() ,
          axis.title.x = element_blank(),
          axis.title.y = element_text(size=rel(.9)),
          axis.text.x = element_text(angle = 90, vjust = 0.2, hjust=1),
          panel.background = element_blank(), 
          strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" )) + 
    guides(color=guide_legend(nrow=1), fill=guide_legend(nrow=1)) +
    scale_y_continuous(expand=c(0,0),labels = scales::percent) 

  if(with_viridis){
    p = p + scale_fill_viridis_d(begin=0,end=1,direction=-1) 
  }
  return(p)
}


plot_crude_proportion_monthly_cases_by_age = function(tmp, days_BRM){

  # use a backward rolling mean to smooth over the last 2 months
  mav <- function(x,n=days_BRM){stats::filter(x,rep(1/n,n), sides=1)} 
  tmp[ , dummy := 1]
  tmp[ , dummy := .N, by = .(code, age)]
  tmp1 = select(subset(tmp, dummy >= days_BRM), code, age, M_cases_monthly, date)
  tmp1[, M_cases_monthly_BRM := as.numeric(mav(M_cases_monthly)), by = c("code", "age")]
  tmp = merge(tmp, tmp1, by = c("code", "age", "M_cases_monthly", "date"))
  
  # find proportion expected cases
  tmp1 = tmp[, list(M_cases_monthly_total = sum(M_cases_monthly_BRM)), by = c("code", "date")]
  tmp = merge(tmp, tmp1, by = c("code", "date"))
  tmp[, M_cases_prop_monthly := M_cases_monthly_BRM / M_cases_monthly_total]
  
  # plot
  deathByAge.first.date <- tmp[, min(date)]
  deathByAge.last.date <- tmp[, max(date)]
  
  tmp1 = subset(tmp, age != "0-24")
  p = ggplot(tmp1, aes(x=date)) +
    geom_bar(aes(y=M_cases_prop_monthly, fill=age), stat='identity',position='fill', alpha = 1, width = 0.95) +
    labs(x='', y='', fill='Age band', col = 'Age band') +
    scale_x_date(expand=c(0,0),date_breaks = "2 months", labels = date_format("%e %b")) +
    coord_cartesian(xlim=c(deathByAge.first.date, deathByAge.last.date), ylim=c(0,1))  +
    theme_bw(base_size=22) + 
    facet_wrap(~loc_label, ncol = 5) +
    theme(legend.position= 'bottom',
          #legend.title=element_text(size=20),
          legend.text=element_text(size=rel(.7)),
          # text = element_text(size=20),
          legend.background=element_blank(),
          legend.key.size = unit(2, "mm"),
          panel.grid.major = element_blank() ,
          panel.grid.minor = element_blank() ,
          axis.text.x = element_text(angle = 90, vjust = 0.2, hjust=1),
          axis.title.x = element_blank(), 
          panel.background = element_blank(), 
          strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" )) + 
    scale_y_continuous(expand=c(0,0),labels = scales::percent)  +
    scale_fill_viridis_d(begin=0,end=1,direction=-1) +
    guides(fill=guide_legend(nrow=1,byrow=TRUE))
  
  return(p)
}


plot_crude_proportion_monthly_cases_by_age_withCI = function(tmp, Age){
  
  # find states which have a significant change in the proportion 
  for(m in seq_along(unique(tmp$code))){
    tmp1 = subset(tmp, code == unique(tmp$code)[m] & age == Age)
    
    tmp1[, dummy := F]
    tmp1[, dummy := CL_diff_cases_monthly < 0 & CU_diff_cases_monthly < 0]
    tmp1[dummy == F, dummy := CL_diff_cases_monthly > 0 & CU_diff_cases_monthly > 0]
    if(any(na.omit(tmp1$dummy))) tmp[code == unique(tmp$code)[m], loc_label := paste0(loc_label, "*")]
  }
  
  # plot
  deathByAge.first.date <- tmp[, min(date)]
  deathByAge.last.date <- tmp[, max(date)]
  
  color_palette = viridis(n = length(unique(tmp$age)), 
                          begin = 0, 
                          end = 1, direction = -1)
  col_Age = color_palette[which(unique(tmp$age) == Age)]
  
  tmp1 = subset(tmp, age == Age)
  p = ggplot(tmp1, aes(x=date)) +
    geom_line(aes(y=M_cases_prop_monthly, col=age)) +
    geom_ribbon(aes(ymin=CL_cases_prop_monthly, ymax=CU_cases_prop_monthly, fill=age), alpha = 0.7) +
    labs(x='', y='Proportion of COVID-19 monthly cases', fill='Age band', col = 'Age band') +
    scale_x_date(expand=c(0,0),date_breaks = "2 months", labels = date_format("%e %b")) +
    coord_cartesian(xlim=c(deathByAge.first.date, deathByAge.last.date), ylim=c(0,1))  +
    theme_bw(base_size=22) + 
    facet_wrap(~loc_label, ncol = 5) +
    theme(legend.position= 'bottom',
          #legend.title=element_text(size=20),
          legend.text=element_text(size=rel(.7)),
          # text = element_text(size=20),
          legend.background=element_blank(),
          legend.key.size = unit(2, "mm"),
          panel.grid.major = element_blank() ,
          panel.grid.minor = element_blank() ,
          axis.title.x = element_blank() ,
          axis.text.x = element_text(angle = 90, vjust = 0.2, hjust=1),
          panel.background = element_blank(), 
          strip.background = element_rect( color="white", fill="white", size=1, linetype="solid" )) + 
    scale_y_continuous(expand=c(0,0),labels = scales::percent) +
    scale_color_manual(values =col_Age ) +
    scale_fill_manual(values = col_Age)

  return(p)
  
}

