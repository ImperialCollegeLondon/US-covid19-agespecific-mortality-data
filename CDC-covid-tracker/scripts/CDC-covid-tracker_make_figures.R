library(rstan)
library(data.table)

tempdir = "~/git/US-covid19-data-scraping/data_visualization/results_predict_deaths_CDC_common_age_strata"

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-tempdir')
  args <- list()
  tempdir <- args_line[[2]]
}

indir = "~/git/US-covid19-data-scraping" # path to the repo
stan_model = "210309d"

source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.R"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-stan_utility_functions.R"))

# path to JHU data
path.to.JHU.data = file.path(indir, "data", "official", paste0("jhu_death_data_padded_210308.rds"))


set.seed(4567)
run_index = round(runif(1,0, 10000))
run_tag = paste0(stan_model, "_", run_index)

outdir.fit = file.path(tempdir, run_tag, "fits")
outdir.fig = file.path(tempdir, run_tag, "figures")
outdir.table = file.path(tempdir, run_tag, "table")

cat("outfile.dir is ", file.path(tempdir, run_tag))
dir.create(file.path(tempdir, run_tag), showWarnings = FALSE)
dir.create(file.path(outdir.fig, "convergence_diagnostics"), showWarnings = FALSE)
dir.create(file.path(outdir.fig, "posterior_predictive_checks"), showWarnings = FALSE)
dir.create(file.path(outdir.fig, "continuous_contribution"), showWarnings = FALSE)

# max age considered
age_max = 105

# load JHU data
JHUData = readRDS(path.to.JHU.data)

#
# Prepare CDC data
last.day = as.Date("2021-03-11")
deathByAge = prepare_CDC_data(last.day, age_max, indir)
#
# Create age maps
create_map_age(age_max)

#
# locations and dates
locations = unique(deathByAge$loc_label) 
dates = unique(deathByAge$date)
dates = dates[(length(dates) - 4):length(dates)]

#
# House-keeping
predictive_checks_table = vector(mode = "list", length = nrow(unique(select(deathByAge, code, date))))  
eff_sample_size_cum = vector(mode = "list", length = nrow(unique(select(deathByAge, code, date))))  
Rhat_cum = vector(mode = "list", length = nrow(unique(select(deathByAge, code, date))))  
eff_sample_size_weekly = vector(mode = "list", length = nrow(unique(select(deathByAge, code, date))))  
Rhat_weekly = vector(mode = "list", length = nrow(unique(select(deathByAge, code, date))))  


j = 1


#
# For every state
# for(m in 1:length(locations)){   
for(m in 1:5){   
  #m = 12
  #
  # for every date
  
  for(t in 2:length(dates)){
    #t = 2
    
    Date = dates[t]
    loc_name = locations[m]
    
    cat("Location ", as.character(loc_name), "\n")
    cat("Date ", as.character(Date), "\n")
    

    # stan data
    stan_data = prepare_stan_data(deathByAge, JHUData, loc_name, Date)
    
    cat("Load fits \n")
    
    # load fit cumulative deaths
    cat("Cumulative \n")
    
    if(!cumulative_less_1){
      file = file.path(outdir.fit, paste0("fit_cumulative_deaths_", Code, "_", Date, "_",run_tag,".rds"))
      fit_cum <- readRDS(file=file)
    } else{ fit_cum = NULL }

    # load fit weekly deaths
    cat("Weekly \n")
    #if(sum(tmp1$weekly_deaths) > 1){ # we cannot fit the model if the sum of deaths is less than 1
    if(!weekly_less_1){ # we cannot fit the model if the sum of deaths is less than 1
      file = file.path(outdir.fit, paste0("fit_weekly_deaths_", Code, "_", Date, "_",run_tag,".rds"))
      fit_weekly <- readRDS(file=file)
    } else{fit_weekly = NULL}
    
    #
    # Convergence diagnostics
    cat("\nMake convergence diagnostics \n")
    make_convergence_diagnostics_stats(fit_cum, cumulative_less_1)
    make_convergence_diagnostics_stats(fit_weekly, weekly_less_1)
    make_convergence_diagnostics_plots(fit_cum, "Cumulative deaths fit", 'cum', cumulative_less_1)
    make_convergence_diagnostics_plots(fit_weekly, "Weekly deaths fit", 'weekly', weekly_less_1)

    
    #
    # Plots predictive checks 
    # Make predictive checks table
    cat("\nMake posterior predive checks table \n")
    pc_cum = make_predictive_checks_table_CDC(fit_cum, "deaths_cum", tmp1, df_age_reporting, cumulative_less_1)
    pc_weekly = make_predictive_checks_table_CDC(fit_weekly, "deaths_weekly", tmp2, df_age_reporting, weekly_less_1)
    predictive_checks_table[[j]] = merge(pc_cum, pc_weekly, by = c("age", "code", "date", "COVID.19.Deaths", "age_from", "age_to",  "loc_label"))
    
    # plot
    cat("\nMake posterior predive checks plots \n")
    p_cum = plot_posterior_predictive_checks(predictive_checks_table[[j]], variable = "COVID.19.Deaths", variable_abbr = "deaths_cum", lab = "Cumulative COVID-19 deaths", Code, Date)
    p_weekly = plot_posterior_predictive_checks(pc_weekly, variable = "weekly_deaths", variable_abbr = "deaths_weekly", lab = "Weekly COVID-19 deaths", Code, Date)
    ggsave(gridExtra::grid.arrange(p_cum[[1]]), file = file.path(outdir.fig, "posterior_predictive_checks", paste0("posterior_predictive_checks_cum_", Code, "_", Date, "_", run_tag,".png") ), w= 10, h = 6)
    ggsave(gridExtra::grid.arrange(p_weekly[[1]]), file = file.path(outdir.fig, "posterior_predictive_checks", paste0("posterior_predictive_checks_weekly_", Code, "_", Date, "_", run_tag,".png") ), w= 10, h = 6)
    
    
    #
    # Plots continuous age distribution pi
    cat("\nMake continuous age distribution plots \n")
    pi_predict_cum = plot_continuous_age_contribution_CDC(fit_cum, df_age_continuous, "cumulative COVID-19 deaths", Code, Date, cumulative_less_1)
    pi_predict_weekly = plot_continuous_age_contribution_CDC(fit_weekly, df_age_continuous, "weekly COVID-19 deaths", Code, Date, weekly_less_1)
    ggsave(pi_predict_cum, file = file.path(outdir.fig, "continuous_contribution", paste0("pi_predict_cum", "_",Code, "_", Date, "_", run_tag,".png") ), w= 8, h = 6)
    ggsave(pi_predict_weekly, file = file.path(outdir.fig, "continuous_contribution", paste0("pi_predict_weekly", "_",Code, "_", Date, "_", run_tag,".png") ), w= 8, h = 6)
    
    
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

eff_sample_size_weekly = as.vector(unlist(eff_sample_size_weekly))
saveRDS(eff_sample_size_weekly, file = file.path(outdir.table, "eff_sample_size_weekly.rds"))

Rhat_cum = as.vector(unlist(Rhat_cum))
saveRDS(Rhat_cum, file = file.path(outdir.table, "Rhat_cum.rds"))

Rhat_weekly = as.vector(unlist(Rhat_weekly))
saveRDS(Rhat_weekly, file = file.path(outdir.table, "Rhat_weekly.rds"))


