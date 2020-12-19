library(data.table)
library(ggplot2)
library(scales)
library(gridExtra)
library(tidyverse)

# jhu
death_data_jhu = readRDS(file.path("data", "official", "jhu_death_data_padded_201217.rds"))

# NYC
death_data_nyc = read.csv(file.path("data", "official", "NYC_deaths_201217.csv"))


# processed data
path_to_data = function(state) file.path("data", "processed", last.day, paste0("DeathsByAge_", state, ".csv"))


make.comparison.plot = function(State, Code, with_CDC = 0){
  
  cat(paste("\n Make comparison plot for", State, "\n"))
  
  # if NYC, use the data from NYC github repository
  if(Code == "NYC"){ 
    death_data_nyc = data.table(death_data_nyc) %>%
      select(DEATH_COUNT, date_of_interest) %>%
      rename(daily_deaths = DEATH_COUNT) %>%
      mutate(source = "City",
             date = as.Date(date_of_interest, format = "%m/%d/%y"),
             cum.deaths = cumsum(daily_deaths))
    
    death_data_scrapping = read.csv(path_to_data(Code)) %>%
      group_by(date, code) %>%
      summarise(cum.deaths = sum(cum.deaths)) %>%
      mutate(source = "City by age")
    death_data_scrapping$date = as.Date(death_data_scrapping$date)
    
    death_data = dplyr::bind_rows(death_data_nyc, death_data_scrapping)
    
    p = ggplot(data = death_data, aes(x = date, y = cum.deaths, col = source)) +
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
    ggsave(file.path("figures", last.day, paste0("comparison.ihme.jhu.depthealth_", Code, ".pdf")), p, w = 8, h =6)
  
  } else{
    
    # else use the JHU data
    death_data_jhu = data.table(subset(death_data_jhu, code == Code)) %>%
      select(code, daily_deaths, date) %>%
      mutate(source = "JHU",
             cum.deaths = cumsum(daily_deaths)) 
    death_data_jhu$date = as.Date(death_data_jhu$date)
    
    death_data_scrapping = read.csv(path_to_data(Code)) %>%
      group_by(date, code) %>%
      summarise(cum.deaths = sum(cum.deaths)) %>%
      mutate(source = "Dept of Health")
    death_data_scrapping$date = as.Date(death_data_scrapping$date)
    
    death_data = dplyr::bind_rows(death_data_jhu, death_data_scrapping)
    
    cat('The last day of data is ', as.character(max(death_data_scrapping$date)))
    
    if(with_CDC){
      death_data_cdc = read.csv(path_to_data("CDC")) %>%
        subset(code == Code) %>%
        group_by(date, code) %>%
        summarise(cum.deaths = sum(cum.deaths)) %>%
        mutate(source = "CDC")
      death_data_cdc$date = as.Date(death_data_cdc$date)
      
      death_data = dplyr::bind_rows(death_data, death_data_cdc)
    }

    p = ggplot(data = death_data, aes(x = date, y = cum.deaths, col = source)) +
      geom_point(size = 1) +
      geom_line(size = 0.5)  +
      scale_x_date(date_breaks = "weeks", labels = date_format("%e %b"), 
                   limits = c(death_data$date[1], 
                              death_data$date[length(death_data$date)])) + 
      theme_bw() + 
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      theme(legend.position="right")+ 
      guides(fill = guide_legend(title="Age")) +
      labs(title = State, y = "Daily deaths (overall population)") 
    ggsave(file.path("figures", last.day, paste0("comparison.jhu.depthealth_", Code, ".pdf")), p, w = 8, h =6)
  }
  
  return(p)
}

make.comparison.plots = function(names, codes){
  p = list()
  for(i in 1:length(names)){
    p[[i]] = make.comparison.plot(names[i], codes[i])
  }
  q = do.call(grid.arrange, c(p, ncol =1))
  ggsave(file.path("figures", last.day, "comparison.ihme.jhu.depthealth_overall.pdf"), q, w = 8, h = 100, limitsize = FALSE)
}

make.time.series.plots = function(codes){
  
  cat("\n Make time series plot \n")
  
  databyage = NULL; data = NULL
  for(Code in codes){
    death_data_scrapping = read.csv(path_to_data(Code)) %>%
        mutate(update = "daily", 
               code = as.character(code),
               date = as.character(date))%>%
        select(code, update, daily.deaths,date,age)
      databyage = rbind(databyage, death_data_scrapping)
      
      death_data_scrapping = read.csv(path_to_data(Code)) %>%
        group_by(date, code) %>%
        summarise(daily_deaths = sum(daily.deaths)) %>%
        ungroup() %>%
        mutate(update = "daily", 
               code = as.character(code),
               date = as.character(date))
      data = rbind(data, death_data_scrapping)
  }

  data$date = as.Date(data$date)
  p = ggplot(data, aes(x = date, y = daily_deaths, linetype = update, color = code)) +
    geom_line() +
    geom_point(size = 0.5) +
    facet_wrap(~code, scale = "free", ncol = 1) +
    scale_x_date(date_breaks = "months", labels = date_format("%e %b"), 
                 limits = c(min(data$date), 
                            max(data$date))) + 
    theme_bw() + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    theme(legend.position="right")+ 
    guides(fill = guide_legend(title="Age")) +
    labs(title = "Time series from Dept of Health", y = "Daily or weekly deaths (overall population)") 
  ggsave(file.path("figures", last.day, "time.series_allstates.pdf"), p, w = 8, h = 100,limitsize = FALSE)
  
  databyage$date = as.Date(databyage$date)
  p = ggplot(databyage, aes(x = date, y = daily.deaths, linetype = update, color = age)) +
    geom_line() +
    geom_point(size = 0.5) +
    facet_wrap(~code, scale = "free", ncol = 1) +
    scale_x_date(date_breaks = "months", labels = date_format("%e %b"), 
                 limits = c(min(databyage$date), 
                            max(databyage$date))) + 
    theme_bw() + 
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    theme(legend.position="bottom")+ 
    guides(fill = guide_legend(title="Age")) +
    labs(title = "Time series from Dept of Health", y = "Daily or weekly deaths (overall population)") 
  ggsave(file.path("figures", last.day, "time.series_allstates_byage.pdf"), p, w = 5, h = 100,limitsize = FALSE)
}

make.death.among.young.plot = function(){
  tmp = as.data.table( read.csv( path_to_data("US") ) )
  
  tmp1 = tmp[, list(max_date = max(date)), by = "code"]
  tmp = merge(tmp, tmp1, by = "code")
  tmp[, islastdate := date == max_date]
  tmp = tmp[islastdate==T,]
  tmp = tmp[!grepl("\\+", age)]
  tmp[, age.from := gsub("(.+)-.*", "\\1", age)]
  tmp = tmp[age.from == 0]
  
  ggplot(tmp, aes(x = code, y = cum.deaths, col = age)) +
    geom_point(size = 4) +
    theme_bw()
  ggsave(file.path("figures", last.day, "death.among.young.pdf"), w = 15, h = 10)
}