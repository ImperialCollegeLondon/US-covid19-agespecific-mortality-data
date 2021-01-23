library(rstan)
library(data.table)

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

path.to.deathByAge.data = file.path(indir, "data", "processed", "2020-10-29", "DeathsByAge_US.csv")
path.to.demographics.data = file.path(indir, "data_visualization", "data", "us_population_withnyc.rds")
path.to.jhu.data = file.path(indir, "data", "official", "jhu_death_data_padded_201207.rds")
path.to.nyc.data = file.path(indir, "data", "official", "NYC_deaths_201207.csv")
path.to.ifr.by.age = file.path(indir, "data_visualization", "data", "ifr-by-age-prior_Levin_continuous_201117.csv")

source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.R"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-stan_utility_functions.R"))

set.seed(3312122)
run_index = round(runif(1,0, 10000))
run_tag = paste0(stan_model, "_", run_index)

outdir.fit = file.path(tempdir, run_tag, "fits")
outdir.fig = file.path(tempdir, run_tag, "figures")
outdir.table = file.path(tempdir, run_tag, "table")

cat("outfile.dir is ", file.path(tempdir, run_tag))
dir.create(file.path(tempdir, run_tag), showWarnings = FALSE)
dir.create(outdir.fit, showWarnings = FALSE)
dir.create(outdir.fig, showWarnings = FALSE)
dir.create(outdir.table, showWarnings = FALSE)

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

# Find time index since 30th cumulative death
deathByAge = find_time_index_since_nth_cum_death(deathByAge, path.to.jhu.data, path.to.nyc.data, 30)
first_date_30thcum_death = unique(select(deathByAge, code, first_date_nthcum_death))

# stratify by month
deathByAge[, month := format(date, "%m")]
death_summary_month = deathByAge[, list(cum.deaths = max(cum.deaths),
                                        monthly_deaths = sum(daily.deaths),
                                        date = max(date)), by = c("code", "age", "first_date_nthcum_death", "loc_label", "month")]

# find age from and age to
age_max = 105
death_summary_month[, age_from := as.numeric(ifelse(grepl("\\+", age), gsub("(.+)\\+", "\\1", age), gsub("(.+)-.*", "\\1", age)))]
death_summary_month[, age_to := as.numeric(ifelse(grepl("\\+", age), age_max, gsub(".*-(.+)", "\\1", age)))]

#
# Create age maps
# create map continuous
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
# find locations and dates
locations = unique(death_summary_month$code[death_summary_month$code != "US"]) 
dates = unique(death_summary_month$date)

#
# House-keeping
df_predict_ntl_age_strata = vector(mode = "list", length = nrow(unique(select(death_summary_month, code, date))))  
df_predict_reporting_age_strata = vector(mode = "list", length = nrow(unique(select(death_summary_month, code, date))))  


j = 1


#
# For every state
for(m in 1:length(locations)){  
  #m = 1
  
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
  
  n_months = nrow(unique(select(tmp, code, date)))
  
  fit_monthly = vector(mode = "list", length = nrow(unique(select(tmp, code, date))))
  t_30thcum_death = which(unique(select(tmp, code, date))$date >= subset(first_date_30thcum_death, code == Code)$first_date_nthcum_death)[1]
  t_30thcum_death = max(t_30thcum_death, min(n_months, 2)) # we don't have monthly death for the first month observed
  
  #
  # Fit for every month
  
  for(t in 1:n_months){
    #t = 1
    
    Date = unique(tmp$date)[t]
    Month = unique(tmp$month)[t]
    
    cat("Location ", as.character(Code), "\n")
    cat("Month ", as.character(Month), "\n")
    
    tmp1 = subset(tmp, month == Month)
    
    cat("Start sampling \n")
    
    #
    # fit cumulative deaths
    cat("Cumulative \n")
    stan_data$deaths = tmp1$cum.deaths
    file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_", Month, "_",run_tag,".rds"))
    fit_cum <- readRDS(file=file)
    
    #
    # fit monthly deaths
    cat("Monthly \n")
    monthly_less_1 = 0
    if(t != 1){
      
      stan_data$deaths = tmp1$monthly_deaths
      
      if(sum(stan_data$deaths) <= 1){ # we cannot fit the model if the sum of deaths is less than 1
        monthly_less_1 = 1
      } else{
        file = file.path(outdir.fit, paste0("fit_monthly_deaths_", Code, "_", Month, "_",run_tag,".rds"))
        fit_monthly[[t]] <- readRDS(file=file)
      }
      
    } 
    
    #
    # Make tables
   
    ## 1. ntl age strata
    cat("\nMake predicted ntl age strate table \n")
    
    # find cum deaths and proportion of deaths per age bands
    df = summarise_abs_deaths(fit_cum, 'deaths_predict_ntl_age_strata', "deaths_cum")
    df1 = summarise_prop_deaths(fit_cum, 'deaths_predict_ntl_age_strata', "deaths_prop_cum")
    df = merge(df, df1, by = 'age_index')
    
    # find monthly deaths and proportion of deaths per age bands
    df1 = summarise_abs_deaths(fit_monthly[[t]], 'deaths_predict_ntl_age_strata', "deaths_monthly", df_ntl_age_strata)
    df2 = summarise_prop_deaths(fit_monthly[[t]], 'deaths_predict_ntl_age_strata', "deaths_prop_monthly", df_ntl_age_strata)
    df1 = merge(df1, df2, by = 'age_index')
    df = merge(df, df1, by = 'age_index')
    
    # find crude estimate of the monthly proportion cases
    df1 = find_crude_cases_monthly(fit_monthly[[t]], 'deaths_predict_ntl_age_strata', "cases_monthly", df_ntl_age_strata, path.to.ifr.by.age)
    df2 = find_crude_prop_cases_monthly(fit_monthly[[t]], 'deaths_predict_ntl_age_strata', "cases_prop_monthly", df_ntl_age_strata, path.to.ifr.by.age)
    df1 = merge(df1, df2, by = 'age_index')
    df = merge(df, df1, by = 'age_index')
    
    # find difference in proportion of deaths from one month to the next
    df1 = find_diff_deaths_monthly(fit_monthly[[t]], fit_monthly[[t_30thcum_death]], 'deaths_predict_ntl_age_strata', "diff_deaths_monthly", df_ntl_age_strata)
    df2 = find_diff_cases_monthly(fit_monthly[[t]], fit_monthly[[t_30thcum_death]], 'deaths_predict_ntl_age_strata', "diff_cases_monthly", df_ntl_age_strata, path.to.ifr.by.age)
    df1 = merge(df1, df2, by = 'age_index')
    df = merge(df, df1, by = 'age_index')
    
    # merge
    df[,code := Code]
    df[,date := Date]
    df_predict_ntl_age_strata[[j]] = merge(df_ntl_age_strata, df, by = c("age_index"))

    
    ## 2. reporting age strata
    cat("\nMake predicted reporting age strate table \n")
    
    # expend map age to add 20 49
    df_age_reporting_w2049 = rbind(df_age_reporting, data.table(age_from = 20, age_to = 49, age_index = 0, age_cat = '20-49', age_from_index = 21, age_to_index = 50))
    
    # find cum deaths and proportion of deaths per age bands
    df = summarise_abs_deaths(fit_cum, 'deaths_predict_reporting_age_strata', "deaths_cum", add_2049 = 1)
    df1 = summarise_prop_deaths(fit_cum, 'deaths_predict_reporting_age_strata', "deaths_prop_cum", add_2049 = 1)
    df = merge(df, df1, by = 'age_index')
    
    # find monthly deaths and proportion of deaths per age bands
    df1 = summarise_abs_deaths(fit_monthly[[t]], 'deaths_predict_reporting_age_strata', "deaths_monthly", df_age_reporting_w2049, add_2049 = 1)
    df2 = summarise_prop_deaths(fit_monthly[[t]], 'deaths_predict_reporting_age_strata', "deaths_prop_monthly", df_age_reporting_w2049, add_2049 = 1)
    df1 = merge(df1, df2, by = 'age_index')
    df = merge(df, df1, by = 'age_index')
    
    # find crude estimate of the monthly proportion cases
    df1 = find_crude_cases_monthly(fit_monthly[[t]], 'deaths_predict_reporting_age_strata', "cases_monthly", df_age_reporting_w2049, path.to.ifr.by.age, add_2049 = 1)
    df2 = find_crude_prop_cases_monthly(fit_monthly[[t]], 'deaths_predict_reporting_age_strata', "cases_prop_monthly", df_age_reporting_w2049, path.to.ifr.by.age, add_2049 = 1)
    df1 = merge(df1, df2, by = 'age_index')
    df = merge(df, df1, by = 'age_index')
    
    # find difference in proportion of deaths from one month to the next
    df1 = find_diff_deaths_monthly(fit_monthly[[t]], fit_monthly[[t_30thcum_death]], 'deaths_predict_reporting_age_strata', "diff_deaths_monthly", df_age_reporting_w2049, add_2049 = 1)
    df2 = find_diff_cases_monthly(fit_monthly[[t]], fit_monthly[[t_30thcum_death]], 'deaths_predict_reporting_age_strata', "diff_cases_monthly", df_age_reporting_w2049, path.to.ifr.by.age, add_2049 = 1)
    df1 = merge(df1, df2, by = 'age_index')
    df = merge(df, df1, by = 'age_index')
    
    # merge
    df[,code := Code]
    df[,date := Date]
    df_predict_reporting_age_strata[[j]] = merge(df_age_reporting_w2049, df, by = c("age_index"))
    
    j = j + 1
  }
}


#
# Save
cat("\nSave \n")

df_predict_ntl_age_strata = do.call("rbind", df_predict_ntl_age_strata)
saveRDS(df_predict_ntl_age_strata, file = file.path(outdir.table, "deaths_predict_ntl_age_strata.rds"))

df_predict_reporting_age_strata = do.call("rbind", df_predict_reporting_age_strata)
saveRDS(df_predict_reporting_age_strata, file = file.path(outdir.table, "df_predict_reporting_age_strata.rds"))

