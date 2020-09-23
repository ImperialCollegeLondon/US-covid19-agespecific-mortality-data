library(tidyverse)

time.daily.update = strptime("22:00:00", "%H:%M:%S")

if(Sys.time() > time.daily.update) last.day = Sys.Date() # today
if(Sys.time() < time.daily.update) last.day = Sys.Date() - 1 # yesterday 

source("utils/make.summary.R") # table.states is a summary of all states extracted
source("utils/make.plots.R")

dir.create(file.path("figures", last.day), showWarnings = FALSE)

`%notin%` <- Negate(`%in%`)

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
