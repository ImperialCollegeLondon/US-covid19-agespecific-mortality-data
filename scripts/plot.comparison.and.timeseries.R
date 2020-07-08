library(tidyverse)

# 1. compare official data (JHU, IHME) on overall death and to scrapped data by age

# 2. time series of all states

time.daily.update = strptime("22:00:00", "%H:%M:%S")

<<<<<<< HEAD
if(Sys.time() > time.daily.update) last.day = Sys.Date() - 1 # yesterday
if(Sys.time() < time.daily.update) last.day = Sys.Date() - 2 # two days ago 

days_week = last.day - 0:6
last.monday = days_week[which(weekdays(days_week) == "Monday")]
last.wednesday = days_week[which(weekdays(days_week) == "Wednesday")]
=======
if(Sys.time() > time.daily.update) last.day = Sys.Date() # today
if(Sys.time() < time.daily.update) last.day = Sys.Date() - 1 # yesterday 
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd

source("utils/make.summary.R") # table.states is a summary of all states extracted
source("utils/make.plots.R")

<<<<<<< HEAD
=======
dir.create(file.path("figures", last.day), showWarnings = FALSE)

>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
`%notin%` <- Negate(`%in%`)

# processed states

<<<<<<< HEAD
table.states.process = subset(table.states, state_name %notin% c("Kansas", "South Carolina", "Iowa", "Idaho", "CDC"))
=======
table.states.process = subset(table.states, state_name %notin% c("CDC"))
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd

# 1.

make.comparison.plots(table.states.process$state_name, table.states.process$code)

# 2.

make.time.series.plots(table.states.process$code)
  