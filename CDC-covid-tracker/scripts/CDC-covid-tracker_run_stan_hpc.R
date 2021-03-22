library(rstan)
library(data.table)
library(dplyr)
library(foreach)
library(doParallel)

indir = "~/git/US-covid19-data-scraping" # path to the repo
outdir = file.path(indir, 'CDC-covid-tracker', "results")

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-outdir')
  args <- list()
  outdir <- args_line[[2]]
}


# stan model
stan_model = "210319d"
path.to.stan.model = file.path(indir, 'CDC-covid-tracker', "stan-models", paste0("CDC-covid-tracker_", stan_model, ".stan"))

# path to JHU data
path.to.JHU.data = file.path(indir, "data", "official", paste0("jhu_death_data_padded_210308.rds"))

# load functions
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-summary_functions.R"))
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-stan_utility_functions.R"))

# tag and directories
set.seed(45678)
run_index = round(runif(1,0, 10000))
run_tag = paste0(stan_model, "_", run_index)

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

#
# Create age maps
create_map_age(age_max)

#
# find locations and dates
locations = unique(deathByAge$loc_label) 
dates = unique(deathByAge$date)
dates = dates[(length(dates) - 4):length(dates)]


#
# read stan model
options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)
model <- rstan::stan_model(path.to.stan.model)
registerDoParallel(length(locations)/4)


#
# For every state
mclapply( 1:length(locations) , function(m) {   
  #m = 2
  
  loc_name = locations[m]
  
  cat("Location ", as.character(loc_name), "\n")
  
  # stan data
  stan_data = prepare_stan_data(deathByAge, JHUData, loc_name)
  
  cat("\n Start sampling \n")
  
  #
  # fit cumulative deaths
  fit_cum <- rstan::sampling(model,data=stan_data,iter=5000,warmup=500,chains=3,
                             seed=run_index,verbose=TRUE,control = list(max_treedepth = 15, adapt_delta = 0.9))
  
  file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_",run_tag,".rds"))
  
  while(!file.exists(file)){
    tryCatch(saveRDS(fit_cum, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
  }
  
  
  return(1)
  
})

