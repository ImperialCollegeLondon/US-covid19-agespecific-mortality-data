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
deathByAge_1_Male = prepare_CDC_data(last.day, age_max, age.specification = 1, sex = 'Male', indir)
deathByAge_1_Male = find_daily_deaths(deathByAge_1_Male)
deathByAge_1_Female = prepare_CDC_data(last.day, age_max, age.specification = 1, sex = 'Female', indir)
deathByAge_1_Female = find_daily_deaths(deathByAge_1_Female)
deathByAge_1 = merge_deathByAge_over_Sex(copy(deathByAge_1_Male), copy(deathByAge_1_Female))

# second part has aggregated Sex
deathByAge_2_Male = prepare_CDC_data(last.day, age_max, age.specification = 2, sex = 'Male', indir)
deathByAge_2_Male = find_daily_deaths(deathByAge_2_Male)
deathByAge_2_Female = prepare_CDC_data(last.day, age_max, age.specification = 2, sex = 'Female', indir)
deathByAge_2_Female = find_daily_deaths(deathByAge_2_Female)
deathByAge_2 = merge_deathByAge_over_Sex(copy(deathByAge_2_Male), copy(deathByAge_2_Female))

deathByAge_2_AllSexes = prepare_CDC_data(last.day, age_max, age.specification = 2, sex = 'All Sexes', indir)
deathByAge_2_AllSexes = find_daily_deaths(deathByAge_2_AllSexes)

deathByAge_2 = anti_join(deathByAge_2, deathByAge_2_AllSexes, by = c('loc_label', 'age', 'date'))
deathByAge_2 = rbind(deathByAge_2, select(deathByAge_2_AllSexes, -Sex))
deathByAge_2 = deathByAge_2[order(loc_label, age, date)]

saveRDS(deathByAge_1, file.path(outdir, paste0('CDC-data-1_', last.day, '.rds')))
saveRDS(deathByAge_2, file.path(outdir, paste0('CDC-data-2_', last.day, '.rds')))

