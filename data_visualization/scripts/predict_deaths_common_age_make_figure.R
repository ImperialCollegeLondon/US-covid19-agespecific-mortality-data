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

path.to.deathByAge.data = file.path(indir, "data", "processed", "2020-12-10", "DeathsByAge_US.csv")
path.to.demographics.data = file.path(indir, "data_visualization", "data", "us_population_withnyc.rds")
path.to.stan.model = file.path(indir, "data_visualization", "stan-models", paste0("predict_DeathsByAge_", stan_model, ".stan"))

source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.R"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-stan_utility_functions.R"))

set.seed(3312112)
run_index = round(runif(1,0, 10000))
run_tag = paste0(stan_model, "_", run_index)

outdir.fit = file.path(tempdir, run_tag, "fits")
outdir.fig = file.path(tempdir, run_tag, "figures")
outdir.table = file.path(tempdir, run_tag, "table")

cat("outfile.dir is ", file.path(tempdir, run_tag))
dir.create(file.path(tempdir, run_tag), showWarnings = FALSE)
dir.create(outdir.fit, showWarnings = FALSE)
dir.create(outdir.table, showWarnings = FALSE)
dir.create(outdir.fig, showWarnings = FALSE)
dir.create(file.path(outdir.fig, "convergence_diagnostics"), showWarnings = FALSE)
dir.create(file.path(outdir.fig, "posterior_predictive_checks"), showWarnings = FALSE)
dir.create(file.path(outdir.fig, "continuous_contribution"), showWarnings = FALSE)

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
predictive_checks_table = vector(mode = "list", length = nrow(unique(select(death_summary_month, code, date))))  
eff_sample_size_cum = vector(mode = "list", length = nrow(unique(select(death_summary_month, code, date))))  
Rhat_cum = vector(mode = "list", length = nrow(unique(select(death_summary_month, code, date))))  
eff_sample_size_monthly = vector(mode = "list", length = nrow(unique(select(death_summary_month, code, date))))  
Rhat_monthly = vector(mode = "list", length = nrow(unique(select(death_summary_month, code, date))))  


j = 1


#
# For every state
for(m in 1:length(locations)){  
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
    #t = 1
    
    Date = unique(tmp$date)[t]
    Month = unique(tmp$month)[t]
    
    cat("Location ", as.character(Code), "\n")
    cat("Month ", as.character(Month), "\n")
    
    tmp1 = subset(tmp, month == Month)
    
    
    cat("Start sampling \n")
    
    #
    # fit cumulative deaths
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
        fit_monthly <- readRDS(file=file)
      }
      
    } else{fit_monthly = NULL}
    
    #
    # Convergence diagnostics
    cat("\nMake convergence diagnostics \n")
    summary = rstan::summary(fit_cum)$summary
    eff_sample_size_cum[[j]] = summary[,9][!is.na(summary[,9])]
    Rhat_cum[[j]] = summary[,10][!is.na(summary[,10])]
    cat("the minimum and maximum effective sample size are ", range(eff_sample_size_cum[[j]]), "\n")
    cat("the minimum and maximum Rhat are ", range(Rhat_cum[[j]]), "\n")
    stopifnot(min(eff_sample_size_cum[[j]]) > 500)
    
    if(!monthly_less_1 & t != 1){
      summary = rstan::summary(fit_monthly)$summary
      eff_sample_size_monthly[[j]] = summary[,9][!is.na(summary[,9])]
      Rhat_monthly[[j]] = summary[,10][!is.na(summary[,10])]
      cat("the minimum and maximum effective sample size are ", range(eff_sample_size_monthly[[j]]), "\n")
      cat("the minimum and maximum Rhat are ", range(Rhat_monthly[[j]]), "\n")
      stopifnot(min(eff_sample_size_monthly[[j]]) > 500)
    }

    posterior_cum <- as.array(fit_cum)
    p1_trace = bayesplot::mcmc_trace(posterior_cum, regex_pars = c("beta", "v_inflation")) + labs(title = "Cumulative deaths fit")
    p1_pairs = gridExtra::arrangeGrob(bayesplot::mcmc_pairs(posterior_cum, regex_pars = c("beta", "v_inflation")), top = "Cumulative deaths fit")
    p1_intervals = bayesplot::mcmc_intervals(posterior_cum, regex_pars = c("beta", "v_inflation")) + labs(title = "Cumulative deaths fit")
    
    if(!monthly_less_1 & t != 1){
      posterior_monthly <- as.array(fit_monthly)
      p2_trace = bayesplot::mcmc_trace(posterior_monthly, regex_pars = c("beta", "v_inflation")) + labs(title = "Monthly deaths fit")
      p2_pairs = gridExtra::arrangeGrob(bayesplot::mcmc_pairs(posterior_monthly, regex_pars = c("beta", "v_inflation")), top = "Monthly deaths fit")
      p2_intervals  = bayesplot::mcmc_intervals(posterior_monthly, regex_pars = c("beta", "v_inflation"), probs = 0.95) + labs(title = "Monthly deaths fit")
    } else{
      p2_trace = ggplot()
      p2_pairs = ggplot()
      p2_intervals = ggplot()
    }
    
    p_trace = gridExtra::grid.arrange(p1_trace, p2_trace, nrow = 2, top = paste(Code, "month", Month))
    p_pairs = gridExtra::grid.arrange(p1_pairs, p2_pairs, top = paste(Code, "month", Month))
    p_intervals = gridExtra::grid.arrange(p1_intervals, p2_intervals, top = paste(Code, "month", Month))
    ggsave(p_trace, file = file.path(outdir.fig, "convergence_diagnostics", paste0("trace_plots_", Code, "_", Month, "_", run_tag,".png") ), w= 8, h = 8)
    ggsave(p_pairs, file = file.path(outdir.fig, "convergence_diagnostics", paste0("pairs_plots_", Code, "_", Month, "_", run_tag,".png") ), w= 8, h = 10)
    ggsave(p_intervals, file = file.path(outdir.fig, "convergence_diagnostics", paste0("intervals_plots_", Code, "_", Month, "_", run_tag,".png") ), w= 8, h = 8)
    

    #
    # Plots predictive checks 

    # Make predictive checks table
    cat("\nMake posterior predive checks table \n")
    pc_cum = make_predictive_checks_table(fit_cum, "deaths_cum", tmp1, df_state_age_strata)
    if(monthly_less_1 | t == 1){
      pc_monthly = copy(pc_cum)
      pc_monthly[, `:=`(M_deaths_monthly = NA,
                        CL_deaths_monthly = NA,
                        CU_deaths_monthly = NA)]
      pc_monthly = select(pc_monthly, -CL_deaths_cum, -CU_deaths_cum, -M_deaths_cum)
    }else{
      pc_monthly = make_predictive_checks_table(fit_monthly, "deaths_monthly", tmp1, df_state_age_strata)
    }
    predictive_checks_table[[j]] = merge(pc_cum, pc_monthly, by = c("age", "code", "date", "cum.deaths", "age_from", "age_to", "monthly_deaths", "month", "loc_label"))
    
    # plot
    cat("\nMake posterior predive checks plots \n")
    p_cum = plot_posterior_predictive_checks(predictive_checks_table[[j]], variable = "cum.deaths", variable_abbr = "deaths_cum", lab = "Cumulative COVID-19 deaths", Code, Month)
    p_monthly = plot_posterior_predictive_checks(pc_monthly, variable = "monthly_deaths", variable_abbr = "deaths_monthly", lab = "Monthly COVID-19 deaths", Code, Month)
    
    ggsave(gridExtra::grid.arrange(p_cum[[1]]), file = file.path(outdir.fig, "posterior_predictive_checks", paste0("posterior_predictive_checks_cum_", Code, "_", Month, "_", run_tag,".png") ), w= 8, h = 6)
    ggsave(gridExtra::grid.arrange(p_monthly[[1]]), file = file.path(outdir.fig, "posterior_predictive_checks", paste0("posterior_predictive_checks_monthly_", Code, "_", Month, "_", run_tag,".png") ), w= 8, h = 6)

    
    #
    # Plots continuous age distribution pi
    cat("\nMake continuous age distribution plots \n")
    pi_predict_cum = plot_continuous_age_contribution(fit_cum, df_age_continuous, "cumulative COVID-19 deaths", Code, Month)
    if(!monthly_less_1 & t != 1){
      pi_predict_monthly = plot_continuous_age_contribution(fit_monthly, df_age_continuous, "monthly COVID-19 deaths", Code, Month)
    } else{
      pi_predict_monthly = ggplot()
    }
    ggsave(pi_predict_cum, file = file.path(outdir.fig, "continuous_contribution", paste0("pi_predict_cum", "_",Code, "_", Month, "_", run_tag,".png") ), w= 8, h = 6)
    ggsave(pi_predict_monthly, file = file.path(outdir.fig, "continuous_contribution", paste0("pi_predict_monthly", "_",Code, "_", Month, "_", run_tag,".png") ), w= 8, h = 6)
    
    
    j = j + 1
    
  }
}


#
# Save
cat("\nSave \n")

predictive_checks_table = do.call("rbind", predictive_checks_table)
saveRDS(predictive_checks_table, file = file.path(outdir.table, "deaths_predict_state_age_strata.rds"))

eff_sample_size_cum = as.vector(unlist(eff_sample_size_cum))
saveRDS(eff_sample_size_cum, file = file.path(outdir.table, "eff_sample_size_cum.rds"))

eff_sample_size_monthly = as.vector(unlist(eff_sample_size_monthly))
saveRDS(eff_sample_size_monthly, file = file.path(outdir.table, "eff_sample_size_monthly.rds"))

Rhat_cum = as.vector(unlist(Rhat_cum))
saveRDS(Rhat_cum, file = file.path(outdir.table, "Rhat_cum.rds"))

Rhat_monthly = as.vector(unlist(Rhat_monthly))
saveRDS(Rhat_monthly, file = file.path(outdir.table, "Rhat_monthly.rds"))


