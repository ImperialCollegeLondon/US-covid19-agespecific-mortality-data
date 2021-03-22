library(rstan)
library(data.table)

indir = "~/git/US-covid19-data-scraping" # path to the repo
outdir = file.path(indir, 'CDC-covid-tracker', "results")

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-outdir')
  args <- list()
  outdir <- args_line[[2]]
}

stan_model = "210319d"

# load functions
source(file.path(indir, "CDC-covid-tracker", "functions", "CDC-covid-tracker-summary_functions.R"))
source(file.path(indir, "CDC-covid-tracker", "functions", "CDC-covid-tracker-stan_utility_functions.R"))

# path to JHU data
path.to.JHU.data = file.path(indir, "data", "official", paste0("jhu_death_data_padded_210308.rds"))

# set directories
set.seed(456781)
run_index = round(runif(1,0, 10000))
run_tag = paste0(stan_model, "_", run_index)

outdir.fit = file.path(outdir, run_tag, "fits")
outdir.fig = file.path(outdir, run_tag, "figures")
outdir.table = file.path(outdir, run_tag, "table")

cat("outfile.dir is ", file.path(outdir, run_tag))
dir.create(file.path(outdir.fig, "convergence_diagnostics"), showWarnings = FALSE)
dir.create(file.path(outdir.fig, "posterior_predictive_checks"), showWarnings = FALSE)
dir.create(file.path(outdir.fig, "continuous_contribution"), showWarnings = FALSE)

# max age considered
age_max = 105

# load JHU data
JHUData = readRDS(path.to.JHU.data)

# Prepare CDC data
last.day = as.Date("2021-03-11")
deathByAge = prepare_CDC_data(last.day, age_max, indir)

# Create age maps
create_map_age(age_max)

# locations and dates
locations = unique(deathByAge$loc_label) 

# House-keeping
predictive_checks_table = vector(mode = "list", length = length(locations))  
eff_sample_size_cum = vector(mode = "list", length =  length(locations))  
Rhat_cum = vector(mode = "list", length =  length(locations))  
LOO = vector(mode = "list", length =  length(locations))  
WAIC = vector(mode = "list", length =  length(locations))  


j = 1


#
# For every state
for(m in 1:length(locations)){   
  
  #m = 2
  
  loc_name = locations[m]
  
  cat("Location ", as.character(loc_name), "\n")
  
  # stan data
  stan_data = prepare_stan_data(deathByAge, JHUData, loc_name)
  
  cat("Load fits \n")
  
  # load fit cumulative deaths
  file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_", run_tag,".rds"))
  fit_cum <- readRDS(file=file)
  

  # Convergence diagnostics
  cat("\nMake convergence diagnostics \n")
  make_convergence_diagnostics_stats(fit_cum)
  make_convergence_diagnostics_plots(fit_cum, "Cumulative deaths fit", 'cum')
  
  # Make predictive checks table
  cat("\nMake posterior predive checks table \n")
  predictive_checks_table[[j]] = make_predictive_checks_table(fit_cum, "deaths_cum", df_week, df_age_reporting, tmp)

  # plot predictive checks table
  cat("\nMake posterior predive checks plots \n")
  plot_posterior_predictive_checks(predictive_checks_table[[j]], variable = "COVID.19.Deaths", variable_abbr = "deaths_cum", lab = "Cumulative COVID-19 deaths")

  # Plots continuous age distribution alpha
  cat("\nMake continuous age distribution plots \n")
  plot_continuous_age_contribution(fit_cum, df_age_continuous, df_week, "cumulative COVID-19 deaths", Code)
  
  j = j + 1
  
  
}


#
# Save
cat("\nSave \n")

predictive_checks_table = do.call("rbind", predictive_checks_table)
saveRDS(predictive_checks_table, file = file.path(outdir.table, "deaths_predict_state_age_strata.rds"))

eff_sample_size_cum = as.vector(unlist(eff_sample_size_cum))
saveRDS(eff_sample_size_cum, file = file.path(outdir.table, "eff_sample_size_cum.rds"))

Rhat_cum = as.vector(unlist(Rhat_cum))
saveRDS(Rhat_cum, file = file.path(outdir.table, "Rhat_cum.rds"))

