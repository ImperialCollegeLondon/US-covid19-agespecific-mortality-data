library(data.table)

indir = "~/git/US-covid19-data-scraping" # path directory to the repository

set.seed(3312122)
run_index = round(runif(1,0, 10000))
run_tag = paste0("201023o_", run_index)

path.to.demographics.data = file.path(indir, "data_visualization", "data", "us_population_withnyc.rds")
path.to.predict_deaths_state_age_strata.results = file.path(indir, "data_visualization", "results_predict_deaths_common_age_strata", run_tag)

outtab.dir = file.path(indir, "data_visualization", "tables_v120")
outfig.dir = file.path(indir, "data_visualization", "figures_v120")

dir.create(outtab.dir, showWarnings = FALSE)
dir.create(outfig.dir, showWarnings = FALSE)

source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.r"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-plot_functions.r"))

#
# Read data
# read demographics by age for loc labels
pop_count = as.data.table( read_pop_count_by_age_us(path.to.demographics.data) )
setnames(pop_count, "state", "loc_label")

# read predicted death by orginal age groups
death.predict = as.data.table( readRDS( file.path(path.to.predict_deaths_state_age_strata.results, "table", "deaths_predict_state_age_strata.rds") ) )
set(death.predict, NULL, 'date', death.predict[,as.Date(date)])
death.predict = merge(death.predict, unique(select(pop_count, code, loc_label)))


#
# Plot predicted cum and monthly deaths vs observed 
p_predicted_observed_deaths = plot_predicted_observed_deaths(death.predict, "cum.deaths", "COVID-19 mortality counts")

#
# Find range of the effective sample size and Rhat and number or runs
eff_sample_size = readRDS(file.path(path.to.predict_deaths_state_age_strata.results, "table", "eff_sample_size_cum.rds"))
Rhat = readRDS(file.path(path.to.predict_deaths_state_age_strata.results, "table", "Rhat_cum.rds"))
n_runs = nrow(unique(select(death.predict, code, date))) 

convergence_diagnostics = list(prettyNum(round(range(eff_sample_size), digits = 2),big.mark=","), round(range(Rhat), digits = 4), n_runs)

#
# Save
ggsave(p_predicted_observed_deaths, file = file.path(outfig.dir, paste0("PredictedDeathsByAge_vs_ObservedDeathsByAge.png")), w = 10, h = 11)
saveRDS(convergence_diagnostics, file = file.path(outtab.dir, "ConvergenceDiagnostics.rds"))

                  