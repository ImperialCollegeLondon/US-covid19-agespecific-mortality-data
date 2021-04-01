library(rstan)
library(data.table)
library(dplyr)
library(tidyverse)
library(viridis)

indir = "~/git/US-covid19-agespecific-mortality-data" # path to the repo
indir = "~/git/US-covid19-data-scraping" # path to the repo
outdir = file.path(indir, 'CDC-covid-tracker', "results")
location.index = 2
stan_model = "210329b"
JOBID = 11496

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
print(args_line)
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-indir')
  stopifnot(args_line[[3]]=='-outdir')
  stopifnot(args_line[[5]]=='-location.index')
  stopifnot(args_line[[7]]=='-stan_model')
  stopifnot(args_line[[9]]=='-JOBID')
  indir <- args_line[[2]]
  outdir <- args_line[[4]]
  location.index <- as.numeric(args_line[[6]])
  stan_model <- args_line[[8]]
  JOBID <- as.numeric(args_line[[10]])
}

# load functions
source(file.path(indir, "CDC-covid-tracker/functions/CDC-covid-tracker-summary_functions.R"))
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-plotting_functions.R"))
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-postprocessing-plotting_functions.R"))
source(file.path(indir, "utils/summary.functions.R"))
source(file.path(indir, "utils/sanity.check.function.R"))
source(file.path(indir, "utils/make.plots.functions.R"))

# set directories
run_tag = paste0(stan_model, "-", JOBID)
outdir.table = file.path(outdir, run_tag, "table")
path_to_JHU_data = file.path(indir, "data/official/jhu_death_data_padded_210321.rds")
states_w_one_day_delay = c()

# find locs
files = list.files(path = outdir.table, pattern = 'predictive')
locs = unique(gsub(paste0(run_tag, '-', "predictive_checks_table_(.+).rds"), "\\1", files))

# for all states
tmp = vector(mode = 'list', length = length(locs))
tmp0 = vector(mode = 'list', length = length(locs))
for(m in seq_along(locs)) 
{
  loc = locs[m]
  
  cat("\n Processing ", loc, '\n')
  
  file = file.path(outdir.table, paste0(run_tag, '-', "predictive_checks_table_", loc,".rds"))
  
  # prepare data table
  data0 = readRDS(file)
  data = select(data0, date, M_deaths_cum, age, code)
  setnames(data, 'M_deaths_cum', 'cum.deaths')
  data[, daily.deaths := as.numeric(NA)]
  data[, age := as.character(age)]
  data[, date := as.Date(date)]
  
  # find dates with data
  dates = unique(sort(data$date))
  
  # ensure that cumulative death is increasing in the data
  data = ensure_increasing_cumulative_deaths(dates = dates, h_data = data)
  
  # find daily deaths
  data = find_daily_deaths(dates = dates, h_data = data, state_code = loc)
  
  # add loc label
  data = merge(data, map_statename_code, by = 'code')
  setnames(data, 'State', 'loc_label')
  
  tmp[[m]] = data
  tmp0[[m]] = data0
}

tmp = do.call('rbind', tmp)
tmp0 = do.call('rbind', tmp0)

# outdir directory
last.day = max(tmp$date)
outdir.pred = file.path(indir, 'CDC-covid-tracker', 'predictions', last.day)
dir.create(outdir.pred, showWarnings = F, recursive = T)

# save prediction table
file = file.path(outdir.pred, 'predictive_table_US.rds')
cat('\n Save file ', file, '\n')
saveRDS(tmp, file = file)

# save plot compare to JHU
JHUData = readRDS(path_to_JHU_data)
# without CI
compare_CDC_JHU_error_plot(CDC_data = tmp, JHU_data = JHUData, 
                           var.cum.deaths.CDC = 'cum.deaths', 
                           outdir = file.path(outdir.pred, 'postprocessing'))

# with CI
compare_CDC_JHU_error_plot_uncertainty(CDC_data = tmp0, JHU_data = JHUData, 
                           outdir = file.path(outdir.pred, 'postprocessing'))

