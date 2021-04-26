library(rstan)
library(data.table)
library(dplyr)

indir = "~/git/US-covid19-data-scraping" # path to the repo
outdir = file.path("~/git/CDC-covid19-agespecific-mortality-data", "data")

# load functions
source(file.path(indir, 'CDC-covid-tracker', "functions.R"))

# max age considered
age_max = 105

# Gather CDC data
last.day = Sys.Date() - 1 # yesterday

# first part only available with Male and Female separation
deathByAge_Male = prepare_CDC_data(last.day, age_max, age.specification = 1, sex = 'Male', indir)
deathByAge_Male = find_daily_deaths(deathByAge_Male)
deathByAge_Female = prepare_CDC_data(last.day, age_max, age.specification = 1, sex = 'Female', indir)
deathByAge_Female = find_daily_deaths(deathByAge_Female)
deathByAge = merge_deathByAge_over_Sex(copy(deathByAge_Male), copy(deathByAge_Female))

deathByAge_AllSexes = prepare_CDC_data(last.day, age_max, age.specification = 1, sex = 'All Sexes', indir)
deathByAge_AllSexes = find_daily_deaths(deathByAge_AllSexes, rm.COVID.19.Deaths = F)
deathByAge_AllSexes = select(deathByAge_AllSexes, -c(date_idx, min_date_idx, max_date_idx))
deathByAge_res = incorporate_AllSexes_boundary_information(deathByAge, deathByAge_AllSexes)

deathByAge_res[!is.na(daily.deaths), min.sum.daily.deaths := NA]
deathByAge_res[!is.na(daily.deaths), max.sum.daily.deaths := NA]
deathByAge_res[!is.na(daily.deaths), sum.daily.deaths := NA]

saveRDS(deathByAge_res, file.path(outdir, paste0('CDC-data_', last.day, '.rds')))
