library(rstan)
library(data.table)
library(dplyr)

indir = "~/git/US-covid19-data-scraping" # path to the repo
outdir = file.path(indir, 'CDC-covid-tracker', "data")

# load functions
source(file.path(indir, 'CDC-covid-tracker', "functions.R"))

# max age considered
age_max = 105

# Gather CDC data
last.day = Sys.Date() - 1 # yesterday
# last.day = as.Date('2021-03-03')
deathByAge = prepare_CDC_data(last.day, age_max, indir)

saveRDS(deathByAge, file.path(outdir, paste0('CDC-data_', last.day, '.rds')))
        
        