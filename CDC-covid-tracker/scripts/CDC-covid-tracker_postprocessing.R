library(rstan)
library(data.table)
library(dplyr)

indir = "~/git/US-covid19-agespecific-mortality-data" # path to the repo
outdir = file.path(indir, 'CDC-covid-tracker', "results")
location.index = 2
stan_model = "210319d3"
JOBID = 782737

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
source(file.path(indir, "CDC-covid-tracker", "functions", "CDC-covid-tracker-summary_functions.R"))
source(file.path(indir, "CDC-covid-tracker", "functions", "CDC-covid-tracker-postprocessing-plotting_functions.R"))
source(file.path(indir, "CDC-covid-tracker", "functions", "CDC-covid-tracker-postprocessing-summary_functions.R"))

# set directories
run_tag = paste0(stan_model, "-", JOBID)
outdir.fit = file.path(outdir, run_tag, "fits")
outdir.fig = file.path(outdir, run_tag, "figure", run_tag)
outdir.table = file.path(outdir, run_tag, "table", run_tag)

# max age considered
age_max = 105

# Prepare CDC data
last.day = as.Date("2021-03-11")
deathByAge = prepare_CDC_data(last.day, age_max, indir)

# Create age maps
create_map_age(age_max)

# locations and dates
locations = unique(deathByAge$loc_label) 

# For every state
loc_name = locations[location.index]
cat("Location ", as.character(loc_name), "\n")

# stan data
cat("Prepare stan data \n")
stan_data = prepare_stan_data(deathByAge, loc_name)

# load fit cumulative deaths
cat("Load fits \n")
file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_", run_tag,".rds"))
fit_cum <- readRDS(file=file)

# Convergence diagnostics
cat("\nMake convergence diagnostics \n")
make_convergence_diagnostics_stats(fit_cum)
make_convergence_diagnostics_plots(fit_cum, "Cumulative deaths fit", 'cum', 
                                   outfile = paste0(outdir.fig, "-convergence_diagnostics-"))

# Make predictive checks table
cat("\nMake posterior predive checks table \n")
predictive_checks_table = make_predictive_checks_table(fit_cum, "deaths_cum", df_week, df_age_reporting, tmp)

# plot predictive checks table
cat("\nMake posterior predive checks plots \n")
plot_posterior_predictive_checks(predictive_checks_table, variable = "COVID.19.Deaths", 
                                 variable_abbr = "deaths_cum", lab = "Cumulative COVID-19 deaths", 
                                 outdir = outdir.fig)

# Plots continuous age distribution alpha
cat("\nMake continuous age distribution plots \n")
plot_continuous_age_contribution(fit_cum, df_age_continuous, df_week, "cumulative COVID-19 deaths", 
                                 outdir = outdir.fig)


#
# Save
cat("\nSave \n")

saveRDS(predictive_checks_table, file = paste0(outdir.table, '-predictive_checks_table_', Code, '.rds'))

saveRDS(eff_sample_size_cum, file = paste0(outdir.table, "-eff_sample_size_cum_", Code, ".rds"))

saveRDS(Rhat_cum, file = paste0(outdir.table, "-Rhat_cum_", Code, ".rds"))

saveRDS(WAIC, file = paste0(outdir.table, "-WAIC_", Code, ".rds"))

saveRDS(LOO, file = paste0(outdir.table, "-LOO_", Code, ".rds"))
