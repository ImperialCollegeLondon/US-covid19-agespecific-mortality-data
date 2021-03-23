library(rstan)
library(data.table)
library(dplyr)
library(foreach)
library(doParallel)

indir = "~/git/US-covid19-data-scraping" # path to the repo
outdir = file.path(indir, 'CDC-covid-tracker', "results")
location.index = 2
stan_model = "210319d"

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-indir')
  stopifnot(args_line[[3]]=='-outdir')
  stopifnot(args_line[[5]]=='-location.index')
  stopifnot(args_line[[7]]=='-stan_model')
  stopifnot(args_line[[9]]=='-JOBID')
  indir <- args_line[[2]]
  outdir <- args_line[[4]]
  location.index <- args_line[[6]]
  stan_model <- args_line[[8]]
  JOBID <- args_line[[10]]
}

# stan model
options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)
path.to.stan.model = file.path(indir, 'CDC-covid-tracker', "stan-models", paste0("CDC-covid-tracker_", stan_model, ".stan"))

# path to JHU data
path.to.JHU.data = file.path(indir, "data", "official", paste0("jhu_death_data_padded_210308.rds"))

# load functions
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-summary_functions.R"))
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-stan_utility_functions.R"))

# tag and directories
run_tag = paste0(stan_model, "_", JOBID)

outdir.fit = file.path(outdir, run_tag, "fits")
outdir.fig = file.path(outdir, run_tag, "figures")
outdir.table = file.path(outdir, run_tag, "table")

cat("outfile.dir is ", file.path(outdir, run_tag))
dir.create(file.path(outdir, run_tag))
dir.create(outdir.fit)
dir.create(outdir.fig)
dir.create(outdir.table)

# max age considered
age_max = 105

# load JHU data
JHUData = readRDS(path.to.JHU.data)
  
# Gather CDC data
# last.day = Sys.Date() - 1 # yesterday 
last.day = as.Date('2021-03-05')
deathByAge = prepare_CDC_data(last.day, age_max, indir)

# Create age maps
create_map_age(age_max)

# find locations and dates
locations = unique(deathByAge$loc_label) 

#
# For a state 
loc_name = locations[location.index]
cat("Location ", as.character(loc_name), "\n")

# stan data
cat("\n Prepare stan data \n")
stan_data = prepare_stan_data(deathByAge, JHUData, loc_name)


cat("\n Start sampling \n")

# fit cumulative deaths
fit_cum <- rstan::sampling(model,data=stan_data,iter=1000,warmup=100,chains=3,
                           seed=JOBID,verbose=TRUE,control = list(max_treedepth = 15, adapt_delta = 0.9))

file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_",run_tag,".rds"))

while(!file.exists(file)){
  tryCatch(saveRDS(fit_cum, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
}



  

  


