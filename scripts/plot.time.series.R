library(tidyverse)

last.day = Sys.Date() - 1 # yesterday 

outdir = file.path("figures", last.day)
dir.create(outdir, showWarnings = FALSE)

source("utils/make_location_table.R") # table.states is a summary of all states extracted
source("utils/make.plots.functions.R")

`%notin%` <- Negate(`%in%`)


#
# Load data
# jhu
death_data_jhu = readRDS(file.path("data", "official", "jhu_death_data_padded_210321.rds"))

# NYC
death_data_nyc = read.csv(file.path("data", "official", "NYC_deaths_210321.csv"))


# processed data
data_US = read.csv(file.path("data", "processed", last.day, paste0("DeathsByAge_", 'US', ".csv")))


#
# processed states
table.states.process = subset(table.states, state_name %notin% c("CDC"))

#
# 1. compare official data (JHU, IHME) on overall death and to scrapped data by age
make.comparison.plots(table.states.process$state_name, table.states.process$code)

#
# 2. time series of all states
make.time.series.plots(table.states.process$code)
  
#
# 3. cumulative death among young
make.death.among.young.plot()
