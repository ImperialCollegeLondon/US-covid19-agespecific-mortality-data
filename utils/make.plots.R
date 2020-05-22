library(data.table)
library(ggplot2)
library(scales)
library(gridExtra)
library(tidyverse)

# ihme
death_data_ihme = read.csv(file.path("data", "official", "ihme_death_data.csv"))

# jhu
death_data_jhu = read.csv(file.path("data", "official", "jhu_death_data_210520.csv"))

# jhu
death_data_nyc = read.csv(file.path("data", "official", "NYC_deaths_200518.csv"))


# scrapped data
path_to_data = function(state) file.path("data", last.day, "processed", paste0("DeathsByAge_", state, ".csv"))


make.comparison.plot = function(State, Code){
  
  cat(paste("\n Make comparison plot for", State, "\n"))
  
  if(Code == "WA"){ # Washington had weekly update
    
    death_data_WA_ihme = data.table(subset(death_data_ihme, state_name == State)) %>%
      select(code, daily_deaths, date) %>%
      mutate(source = "IHME",
             date = as.Date(date)) 
    days_week = weekdays(death_data_WA_ihme$date)
    first.sunday = death_data_WA_ihme$date[which(days_week == "Sunday")][1] 
    last.sunday = death_data_WA_ihme$date[which(days_week == "Sunday")][length(which(days_week == "Sunday"))]
    sundays = death_data_WA_ihme$date[which(days_week == "Sunday")]
    dvec <- first.sunday + 0:(nrow(subset(death_data_WA_ihme, date >= first.sunday & date <= last.sunday)) -1)
    dweek <- as.numeric(dvec-dvec[1]) %/% 7
    death_data_WA_ihme = subset(death_data_WA_ihme, date >= first.sunday & date <= last.sunday) %>%
      mutate(week = dweek) %>%
      group_by(week, source, code) %>%
      summarise(weekly_deaths = sum(daily_deaths)) %>%
      ungroup() %>%
      mutate(date = sundays) %>%
      select(source, code, weekly_deaths, date)
    
    death_data_WA_jhu = data.table(subset(death_data_jhu, state_name == State)) %>%
      select(code, daily_deaths, date) %>%
      mutate(source = "JHU",
             date = as.Date(date)) 
    days_week = weekdays(death_data_WA_jhu$date)
    first.sunday = death_data_WA_jhu$date[which(days_week == "Sunday")][1] 
    last.sunday = death_data_WA_jhu$date[which(days_week == "Sunday")][length(which(days_week == "Sunday"))]
    sundays = death_data_WA_jhu$date[which(days_week == "Sunday")]
    dvec <- first.sunday + 0:(nrow(subset(death_data_WA_jhu, date >= first.sunday & date <= last.sunday)) -1)
    dweek <- as.numeric(dvec-dvec[1]) %/% 7
    death_data_WA_jhu = subset(death_data_WA_jhu, date >= first.sunday & date <= last.sunday) %>%
      mutate(week = dweek) %>%
      group_by(week, source, code) %>%
      summarise(weekly_deaths = sum(daily_deaths)) %>%
      ungroup() %>%
      mutate(date = sundays) %>%
      select(source, code, weekly_deaths, date)
    
    death_data_WA_scrapping = read.csv(path_to_data(Code)) %>%
      group_by(date, code) %>%
      summarise(weekly_deaths = sum(weekly.deaths)) %>%
      mutate(source = "Dept of Health") 
    death_data_WA_scrapping$date = as.Date(death_data_WA_scrapping$date)
    
    death_data_WA = dplyr::bind_rows(death_data_WA_jhu, death_data_WA_ihme, death_data_WA_scrapping)
    
    p = ggplot(data = death_data_WA, aes(x = as.Date(date), y = weekly_deaths, col = source)) +
      geom_point() +
      geom_line() +
      scale_x_date(date_breaks = "weeks", labels = date_format("%e %b"), 
                   limits = c(death_data_WA$date[1], 
                              death_data_WA$date[length(death_data_WA$date)])) + 
      theme_bw() + 
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      theme(legend.position="right")+ 
      guides(fill = guide_legend(title="Age")) +
      labs(title = State, y = "Weekly deaths (overall population)") 
     ggsave(paste0("figures/comparison.ihme.jhu.depthealth_", Code, ".png"), p, w = 8, h =6)
    
  } else if(Code == "NYC"){ 
    death_data_nyc = data.table(death_data_nyc) %>%
      select(Deaths, DATE_OF_INTEREST) %>%
      rename(daily_deaths = Deaths) %>%
      mutate(source = "City",
             date = as.Date(DATE_OF_INTEREST, format = "%m/%d/%y"))
    
    death_data_scrapping = read.csv(path_to_data(Code)) %>%
      group_by(date, code) %>%
      summarise(daily_deaths = sum(daily.deaths)) %>%
      mutate(source = "Dept of Health")
    death_data_scrapping$date = as.Date(death_data_scrapping$date)
    
    death_data = dplyr::bind_rows(death_data_nyc, death_data_scrapping)
    
    p = ggplot(data = death_data, aes(x = date, y = daily_deaths, col = source)) +
      geom_point() +
      geom_line()  +
      scale_x_date(date_breaks = "weeks", labels = date_format("%e %b"), 
                   limits = c(death_data$date[1], 
                              death_data$date[length(death_data$date)])) + 
      theme_bw() + 
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      theme(legend.position="right")+ 
      guides(fill = guide_legend(title="Age")) +
      labs(title = State, y = "Daily deaths (overall population)") 
    ggsave(paste0("figures/comparison.ihme.jhu.depthealth_", Code, ".png"), p, w = 8, h =6)
  
  } else{
    
    death_data_ihme = data.table(subset(death_data_ihme, state_name == State)) %>%
      select(code, daily_deaths, date) %>%
      mutate(source = "IHME")
    death_data_ihme$date = as.Date(death_data_ihme$date)
    
    death_data_jhu = data.table(subset(death_data_jhu, state_name == State)) %>%
      select(code, daily_deaths, date) %>%
      mutate(source = "JHU")
    death_data_jhu$date = as.Date(death_data_jhu$date)
    
    death_data_scrapping = read.csv(path_to_data(Code)) %>%
      group_by(date, code) %>%
      summarise(daily_deaths = sum(daily.deaths)) %>%
      mutate(source = "Dept of Health")
    death_data_scrapping$date = as.Date(death_data_scrapping$date)
    
    death_data = dplyr::bind_rows(death_data_jhu, death_data_ihme, death_data_scrapping)
    
    p = ggplot(data = death_data, aes(x = date, y = daily_deaths, col = source)) +
      geom_point() +
      geom_line()  +
      scale_x_date(date_breaks = "weeks", labels = date_format("%e %b"), 
                   limits = c(death_data$date[1], 
                              death_data$date[length(death_data$date)])) + 
      theme_bw() + 
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      theme(legend.position="right")+ 
      guides(fill = guide_legend(title="Age")) +
      labs(title = State, y = "Daily deaths (overall population)") 
    ggsave(paste0("figures/comparison.ihme.jhu.depthealth_", Code, ".png"), p, w = 8, h =6)
  }
  
  return(p)
}

make.comparison.plots = function(names, codes){
  p = list()
  for(i in 1:length(names)){
    p[[i]] = make.comparison.plot(names[i], codes[i])
  }
  q = do.call(grid.arrange,p)
  ggsave(paste0("figures/comparison.ihme.jhu.depthealth_overall.png"), q, w = 18, h = 14)
}

make.time.series.plots = function(codes){
  
  cat("\n Make time series plot \n")
  
  data = NULL
  for(Code in codes){
    if(Code == "WA"){
      death_data_scrapping = read.csv(path_to_data(Code)) %>%
        group_by(date, code) %>%
        summarise(daily_deaths = sum(weekly.deaths)) %>%
        ungroup() %>%
        mutate(update = "weekly", 
               code = as.character(code),
               date = as.character(date))
      data = rbind(data, death_data_scrapping)
    }else{
      death_data_scrapping = read.csv(path_to_data(Code)) %>%
        group_by(date, code) %>%
        summarise(daily_deaths = sum(daily.deaths)) %>%
        ungroup() %>%
        mutate(update = "daily", 
               code = as.character(code),
               date = as.character(date))
      data = rbind(data, death_data_scrapping)
    }
  }

  data$date = as.Date(data$date)
  p = ggplot(data, aes(x = date, y = daily_deaths, linetype = update, color = code)) +
    geom_line() +
    geom_point(size = 0.5) +
    facet_wrap(~code, scale = "free") +
    scale_x_date(date_breaks = "months", labels = date_format("%e %b"), 
                 limits = c(min(data$date), 
                            max(data$date))) + 
    theme_bw() + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    theme(legend.position="right")+ 
    guides(fill = guide_legend(title="Age")) +
    labs(title = "Time series from Dept of Health", y = "Daily or weekly deaths (overall population)") 
  ggsave(paste0("figures/time.series_allstates.png"), p, w = 15, h = 10)
}
