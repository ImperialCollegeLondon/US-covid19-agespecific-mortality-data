# 1. compare official data (JHU, IHME) on overall death and to scrapped data by age
# 2. time series of all states

source("utils/make.plots.R")

date = Sys.Date() - 1

# 1.

make.comparison.plots("Georgia", "GA")
make.comparison.plots("Connecticut", "CT")
make.comparison.plots("Colorado", "CO")
make.comparison.plots("Texas", "TX")
make.comparison.plots("Florida", "FL")
make.comparison.plots("Washington", "WA")
make.comparison.plots("New York", "NYC")

# 2.

make.time.series.plots(c("GA", "NYC", "TX", "FL", "CO", "CT", "WA"))
