library(rstan)
library(data.table)
library(dplyr)
library(foreach)
library(doParallel)

indir = "~/git/US-covid19-data-scraping" # path to the repo
tempdir = file.path(indir, "data_visualization/results_predict_deaths_CDC_common_age_strata")

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-tempdir')
  args <- list()
  tempdir <- args_line[[2]]
}


# stan model
stan_model = "210309d"
path.to.stan.model = file.path(indir, "data_visualization", "stan-models", paste0("predict_DeathsByAge_", stan_model, ".stan"))

# path to JHU data
path.to.JHU.data = file.path(indir, "data", "official", paste0("jhu_death_data_padded_210308.rds"))

# load functions
source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.R"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-stan_utility_functions.R"))

# tag and directories
set.seed(4567)
run_index = round(runif(1,0, 10000))
run_tag = paste0(stan_model, "_", run_index)

outdir.fit = file.path(tempdir, run_tag, "fits")
outdir.fig = file.path(tempdir, run_tag, "figures")
outdir.table = file.path(tempdir, run_tag, "table")

cat("outfile.dir is ", file.path(tempdir, run_tag))
dir.create(file.path(tempdir, run_tag))
dir.create(outdir.fit)
dir.create(outdir.fig)
dir.create(outdir.table)

# max age considered
age_max = 105

# load JHU data
JHUData = readRDS(path.to.JHU.data)
  
# Gather CDC data
last.day = Sys.Date() - 1 # yesterday 
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
  #m = 1
  
  #
  # Fit for every selected dates
  for(t in 2:length(dates)){
    #t = 2
    
    Date = dates[t]
    loc_name = locations[m]
    
    cat("Location ", as.character(loc_name), "\n")
    cat("Date ", as.character(Date), "\n")
    
    # stan data
    stan_data = prepare_stan_data(deathByAge, JHUData, loc_name, Date)
    
    cat("\n Start sampling \n")
    
    #
    # fit cumulative deaths
    if(!cumulative_less_1){
      stan_data$deaths = tmp1$COVID.19.Deaths
      fit_cum <- rstan::sampling(model,data=stan_data,iter=1000,warmup=100,chains=3,
                                 seed=run_index,verbose=TRUE,control = list(max_treedepth = 15, adapt_delta = 0.9)) 
      file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_", Date, "_",run_tag,".rds"))
      while(!file.exists(file)){
        tryCatch(saveRDS(fit_cum, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
      }
    }
    
    
    #
    # fit biweekly deaths
    if(!weekly_less_1){ 
      stan_data$deaths = tmp1$weekly_deaths
      fit_weekly <- rstan::sampling(model,data=stan_data,iter=10000,warmup=1000,chains=3,
                                    seed=run_index,verbose=TRUE,control = list(max_treedepth = 15, adapt_delta = 0.9)) 
      file = file.path(outdir.fit, paste0("fit_weekly_deaths_", Code, "_", Date, "_",run_tag,".rds"))
      while(!file.exists(file)){
        tryCatch(saveRDS(fit_weekly, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
      }
    }
    
  }
  
  return(1)
  
})

