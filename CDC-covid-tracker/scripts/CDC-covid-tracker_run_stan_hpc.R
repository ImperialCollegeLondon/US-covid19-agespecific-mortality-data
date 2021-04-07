library(rstan)
library(data.table)
library(dplyr)
library(foreach)
library(doParallel)

indir = "~/git/US-covid19-data-scraping" # path to the repo
outdir = file.path(indir, 'CDC-covid-tracker', "results")
location.index = 1
stan_model = "210406d"
JOBID = 12

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

# stan model
#options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)
path.to.stan.model = file.path(indir, 'CDC-covid-tracker', "stan-models", paste0("CDC-covid-tracker_", stan_model, ".stan"))

# path to JHU data
path.to.JHU.data = file.path(indir, "data", "official", paste0("jhu_death_data_padded_210308.rds"))

# load functions
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-summary_functions.R"))
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-plotting_functions.R"))
source(file.path(indir, 'CDC-covid-tracker', "functions", "CDC-covid-tracker-stan_utility_functions.R"))

# tag and directories
run_tag = paste0(stan_model, "-", JOBID)

outdir.fit = file.path(outdir, run_tag, "fits")
stopifnot(dir.exists(outdir.fit))

cat("\n outfile.dir is ", file.path(outdir, run_tag), '\n')

# max age considered
age_max = 105
  
# Gather CDC data
# last.day = Sys.Date() - 1 # yesterday 
last.day = as.Date('2021-03-03')
deathByAge = prepare_CDC_data(last.day, age_max, indir)

# compare to JHU data
JHUData = readRDS(path.to.JHU.data)
compare_CDC_JHU_error_plot(CDC_data = deathByAge, JHU_data = JHUData, 
                           var.cum.deaths.CDC = 'COVID.19.Deaths', 
                           outdir = file.path(outdir, run_tag, 'figure', run_tag))

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
stan_data = prepare_stan_data(deathByAge, loc_name)

if(grepl('210319d2|210319d3', stan_model)){
  cat("\n Using a GP \n")
  stan_data$age = matrix(stan_data$age, nrow = 106, ncol = 1)
}
if(grepl('210326|210329|210330|210406', stan_model)){
  cat("\n Using splines \n")
  stan_data = add_splines_stan_data(stan_data)
}
if(grepl('210406', stan_model)){
  cat("\n Using CAR \n")
  stan_data = add_adjacency_matrix_stan_data(stan_data)
}


cat("\n Start sampling \n")

# fit cumulative deaths

model = rstan::stan_model(path.to.stan.model)

fit_cum <- rstan::sampling(model,data=stan_data,iter=5000,warmup=500,chains=3, seed=JOBID,verbose=TRUE, control = list(max_treedepth = 15))

file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_",run_tag,".rds"))
cat('\n Save file', file, '\n')
while(!file.exists(file)){
  tryCatch(saveRDS(fit_cum, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
}






