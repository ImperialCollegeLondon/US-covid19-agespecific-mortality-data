library(rstan)
library(data.table)
library(dplyr)
library(foreach)
library(doParallel)

tempdir = "~/git/US-covid19-data-scraping/data_visualization/results_predict_deaths_CDC_common_age_strata"

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-tempdir')
  args <- list()
  tempdir <- args_line[[2]]
}

indir = "~/git/US-covid19-data-scraping" # path to the repo

# stan model
stan_model = "201023p"
path.to.stan.model = file.path(indir, "data_visualization", "stan-models", paste0("predict_DeathsByAge_", stan_model, ".stan"))

# load functions
source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.R"))

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

# Gather CDC data
last.day = Sys.Date() - 1 # yesterday 
deathByAge = prepare_CDC_data(last.day, indir)
setnames(deathByAge, c('Age.group', 'State'), c("age", "loc_label"))

# rm US and add code
deathByAge = subset(deathByAge, loc_label != 'United States')
deathByAge = merge(deathByAge, map_statename_code, by.x = 'loc_label', by.y = 'State')

# find age from and age to
age_max = 105
deathByAge[, age_from := as.numeric(ifelse(grepl("\\+", age), gsub("(.+)\\+", "\\1", age), gsub("(.+)-.*", "\\1", age)))]
deathByAge[, age_to := as.numeric(ifelse(grepl("\\+", age), age_max, gsub(".*-(.+)", "\\1", age)))]


#
# Create age maps
# create map by 5-year age bands
df_age_continuous = data.table(age_from = 0:age_max,
                               age_to = 0:age_max,
                               age_index = 0:age_max,
                               age = c(0.1, 1:age_max))

# create map for reporting age groups
df_age_reporting = data.table(age_from = c(0,1,5,15,25,35,45,55,65,75,85),
                              age_to = c(0,4,14,24,34,44,54,64,74,84,age_max),
                              age_index = 1:11,
                              age_cat = c('0-0', '1-4', '5-14', '15-24', '25-34', '35-44', '45-54', '55-64', '65-74', '75-84', '85+'))
df_age_reporting[, age_from_index := which(df_age_continuous$age_from == age_from), by = "age_cat"]
df_age_reporting[, age_to_index := which(df_age_continuous$age_to == age_to), by = "age_cat"]

# create map for 4 new age groups
df_ntl_age_strata = data.table(age_cat = c("0-24", "25-49", "50-74", "75+"),
                               age_from = c(0, 25, 50, 75),
                               age_to = c(24, 49, 74, age_max),
                               age_index = 1:4)
df_ntl_age_strata[, age_from_index := which(df_age_continuous$age_from == age_from), by = "age_cat"]
df_ntl_age_strata[, age_to_index := which(df_age_continuous$age_to == age_to), by = "age_cat"]


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
  #m = 12
  
  loc_name = locations[m]
  
  cat("Location ", as.character(loc_name), "\n")
  
  tmp = subset(deathByAge, loc_label == loc_name)
  tmp = tmp[order(date, age_from)]
  stopifnot(all(tmp$age_from <= tmp$age_to))
  
  #
  # Fit for every selected dates
  for(t in 2:length(dates)){
    #t = 2
    
    Date = dates[t]
    Code = unique(tmp$code)
      
    cat("Location ", as.character(loc_name), "\n")
    cat("Date ", as.character(Date), "\n")
    
    tmp1 = subset(tmp, date == Date)

    # create map of original age groups without NA
    tmp1 = subset(tmp1, !is.na( COVID.19.Deaths ))
    df_state_age_strata = unique(select(tmp1, age_from, age_to, age))
    df_state_age_strata[, age_index := 1:nrow(df_state_age_strata)]
    df_state_age_strata[, age_from_index := which(df_age_continuous$age_from == age_from), by = "age"]
    df_state_age_strata[, age_to_index := which(df_age_continuous$age_to == age_to), by = "age"]
    
    # stan data
    stan_data = list(
      A = nrow(df_age_continuous),
      age = df_age_continuous$age,
      age2 = (df_age_continuous$age)^2,
      B = nrow(df_state_age_strata), 
      age_from_state_age_strata = df_state_age_strata$age_from_index,
      age_to_state_age_strata = df_state_age_strata$age_to_index,
      C = nrow(df_ntl_age_strata), 
      age_from_ntl_age_strata = df_ntl_age_strata$age_from_index,
      age_to_ntl_age_strata = df_ntl_age_strata$age_to_index,
      D = nrow(df_age_reporting), 
      age_from_reporting_age_strata = df_age_reporting$age_from_index,
      age_to_reporting_age_strata = df_age_reporting$age_to_index
    )
    
    cat("\n Start sampling \n")
    
    #
    # fit cumulative deaths
    stan_data$deaths = tmp1$COVID.19.Deaths
    fit_cum <- rstan::sampling(model,data=stan_data,iter=10000,warmup=1000,chains=3,seed=run_index,verbose=TRUE,control = list(max_treedepth = 15, adapt_delta = 0.9)) 
    file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_", Date, "_",run_tag,".rds"))
    while(!file.exists(file)){
      tryCatch(saveRDS(fit_cum, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
    }
    
    #
    # fit biweekly deaths
    tmp2 = subset(tmp, date == dates[t-1] & !is.na(COVID.19.Deaths) & age %in% tmp1$age)
    tmp1 = subset(tmp1, age %in% tmp2$age)
    tmp1$weekly_deaths = tmp1$COVID.19.Deaths - tmp2$COVID.19.Deaths
    stopifnot(all(tmp1$weekly_deaths >= 0))
    
    if(sum(tmp1$weekly_deaths) > 1){ # we cannot fit the model if the sum of deaths is less than 1
      stan_data$deaths = tmp1$weekly_deaths
      fit_weekly <- rstan::sampling(model,data=stan_data,iter=10000,warmup=1000,chains=3,seed=run_index,verbose=TRUE,control = list(max_treedepth = 15, adapt_delta = 0.9)) 
      file = file.path(outdir.fit, paste0("fit_weekly_deaths_", Code, "_", Date, "_",run_tag,".rds"))
      while(!file.exists(file)){
        tryCatch(saveRDS(fit_weekly, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
      }
    }
    
  }
  
  return(1)
  
})

