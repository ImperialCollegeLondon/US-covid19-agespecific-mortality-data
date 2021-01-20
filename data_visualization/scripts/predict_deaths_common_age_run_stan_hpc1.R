library(rstan)
library(data.table)
library(foreach)
library(doParallel)

tempdir = "~/git/US-covid19-data-scraping/data_visualization/results_predict_deaths_common_age_strata"

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-tempdir')
  args <- list()
  tempdir <- args_line[[2]]
}

indir = "~/git/US-covid19-data-scraping" # path to the repo
stan_model = "201023o"

path.to.deathByAge.data = file.path(indir, "data", "processed", "2020-12-10", "DeathsByAge_US.csv")
path.to.demographics.data = file.path(indir, "data_visualization", "data", "us_population_withnyc.rds")
path.to.stan.model = file.path(indir, "data_visualization", "stan-models", paste0("predict_DeathsByAge_", stan_model, ".stan"))

source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.R"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-stan_utility_functions.R"))

set.seed(33121122)
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

#
# read demographics by age to get location label
pop_count = as.data.table( read_pop_count_by_age_us(path.to.demographics.data) )
setnames(pop_count, "state", "loc_label")
pop_info = unique(select(pop_count, code, loc_label))

#
# Read death by age	
deathByAge = as.data.table( read.csv( path.to.deathByAge.data ) )
set(deathByAge, NULL, 'date', deathByAge[,as.Date(date)])
deathByAge = merge(deathByAge, pop_info, by = c("code"))

# stratify by month
deathByAge[, month := format(date, "%m")]
death_summary_month = deathByAge[, list(cum.deaths = max(cum.deaths),
                                        monthly_deaths = sum(daily.deaths),
                                        date = max(date)), by = c("code", "age", "loc_label", "month")]

# find age from and age to
age_max = 105
death_summary_month[, age_from := as.numeric(ifelse(grepl("\\+", age), gsub("(.+)\\+", "\\1", age), gsub("(.+)-.*", "\\1", age)))]
death_summary_month[, age_to := as.numeric(ifelse(grepl("\\+", age), age_max, gsub(".*-(.+)", "\\1", age)))]

#
# Create age maps
# create map by 5-year age bands
df_age_continuous = data.table(age_from = 0:age_max,
                               age_to = 0:age_max,
                               age_index = 0:age_max,
                               age = c(0.1, 1:age_max))

# create map for reporting age groups
df_age_reporting = data.table(age_from = c(0,10,20,35,50,65,80),
                              age_to = c(9,19,34,49,64,79,age_max),
                              age_index = 1:7,
                              age_cat = c("0-9", "10-19", "20-34", "35-49", "50-64", "65-79", "80+"))
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
# read stan model
options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)
model <- rstan::stan_model(path.to.stan.model)

#
# find locations and dates
locations = unique(death_summary_month$code[death_summary_month$code != "US"]) 
dates = unique(death_summary_month$date)

#
# setup parallel backend to use many processors
registerDoParallel(length(locations)/4)

#
# For every state
mclapply( 1:5 , function(m) {   
  #m = 12
  
  Code = locations[m]
  
  cat("Location ", as.character(Code), "\n")
  
  tmp = subset(death_summary_month, code == Code)
  tmp = tmp[order(date, age_from)]
  stopifnot(all(tmp$age_from <= tmp$age_to))
  
  # create map of original age groups
  df_state_age_strata = unique(select(tmp, age_from, age_to, age))
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
  
  #
  # Fit for every month
  
  for(t in 1:nrow(unique(select(tmp, code, date)))){
    #t = 2
    
    Date = unique(tmp$date)[t]
    Month = unique(tmp$month)[t]
    
    cat("Location ", as.character(Code), "\n")
    cat("Month ", as.character(Month), "\n")
    
    tmp1 = subset(tmp, month == Month)
    
    cat("Start sampling \n")
    
    #
    # fit cumulative deaths
    stan_data$deaths = tmp1$cum.deaths
    fit_cum <- rstan::sampling(model,data=stan_data,iter=10000,warmup=1000,chains=3,seed=run_index,verbose=TRUE,control = list(max_treedepth = 15, adapt_delta = 0.9)) 
    file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_", Month, "_",run_tag,".rds"))
    while(!file.exists(file)){
      tryCatch(saveRDS(fit_cum, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
    }
    
    #
    # fit monthly deaths
    monthly_less_1 = 0
    if(t != 1){
      
      tmp1$monthly_deaths = tmp1$cum.deaths - subset(tmp, date == unique(tmp$date)[t-1])$cum.deaths
      stan_data$deaths = tmp1$monthly_deaths
      
      if(sum(stan_data$deaths) > 1){ # we cannot fit the model if the sum of deaths is less than 1
        fit_monthly <- rstan::sampling(model,data=stan_data,iter=10000,warmup=1000,chains=3,seed=run_index,verbose=TRUE,control = list(max_treedepth = 15, adapt_delta = 0.9)) 
        file = file.path(outdir.fit, paste0("fit_monthly_deaths_", Code, "_", Month, "_",run_tag,".rds"))
        while(!file.exists(file)){
          tryCatch(saveRDS(fit_monthly, file=file), error=function(e){cat("ERROR :",conditionMessage(e), ", let's try again \n")})
        }
      }
    }
  }
  return(1)
})


