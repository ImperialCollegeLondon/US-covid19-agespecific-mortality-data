library(data.table)

indir = "~/git/US-covid19-data-scraping" # path directory to the repository

set.seed(3312112)
run_index = round(runif(1,0, 10000))
run_tag = paste0("201023o_", run_index)

lastDate = "2020-12-10"
path.to.demographics.data = file.path(indir, "data_visualization", "data", "us_population_withnyc.rds")
path.to.jhu.data = file.path(indir, "data", "official", "jhu_death_data_padded_201207.rds")
path.to.nyc.data = file.path(indir, "data", "official", "NYC_deaths_201207.csv")
path.to.deathByAge.data = file.path(indir, "data", "processed", lastDate, "DeathsByAge_US.csv")
path.to.predict_deaths_ntl_age_strata = file.path(indir, "data_visualization", "results_predict_deaths_common_age_strata", run_tag, "table", "deaths_predict_ntl_age_strata.rds")

outtab.dir = file.path(indir, "data_visualization", "tables")
outfig.dir = file.path(indir, "data_visualization", "figures")

source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.r"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-plot_functions.r"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-table_functions.r"))


#
# Read data
# read death by age	
deathByAge = as.data.table( read.csv( path.to.deathByAge.data ) )
set(deathByAge, NULL, 'date', deathByAge[,as.Date(date)])

# read demographics by age
pop_count = as.data.table( read_pop_count_by_age_us(path.to.demographics.data) )
setnames(pop_count, "state", "loc_label")

# read predicted death by 4 age groups 
death.predict = as.data.table( readRDS( path.to.predict_deaths_ntl_age_strata ) )
set(death.predict, NULL, 'date', death.predict[,as.Date(date)])
death.predict[, code := as.character(code)]
setnames(death.predict, 'age_cat', "age")

# find observation days
death.predict[, month := format(date, "%m")]
dates_data = unique(select(deathByAge, code, date))
dates_data[, month := format(date, "%m")]
death.predict = merge(select(death.predict, -date), dates_data, by = c("code", "month"),  allow.cartesian=TRUE)


# create loc division map
loc_div = data.table(code = c(c("CT", "ME", "MA", "NH", "RI", "VT"), c("NJ", "NY", "PA", "NYC"), c("IL", "IN", "MI", "OH", "WI"), c("IA", "KS", "MN", "MO", "NE", "ND", "SD"),
                              c("DE", "DC", "FL", "GA", "MD", "NC", "SC", "VA", "WV"), c("AL", "KY", "MS", "TN", "AR", "LA", "OK", "TX"),c("AZ", "CO", "ID", "MT", "NV", "NM", "UT", "WY"),
                              c("AK", "CA", "HI", "OR", "WA")),
                     division = c(rep("New England", 6), rep("Middle Atlantic", 4), rep("East North Central", 5), rep("West North Central", 7), 
                                  rep("South Atlantic", 9), rep("South Central", 8), rep("Mountain", 8), rep("Pacific", 5)))

#
# Find associated pop count
death_summary = find_pop_count(death.predict, pop_count)

#
# Add the US census division 
death_summary = merge(death_summary, loc_div, by = "code")

#
# Find time index since 10th cumulative death
death_summary = find_time_index_since_nth_cum_death(death_summary, path.to.jhu.data, path.to.nyc.data, 10)

#
# Find mortality rate
death_summary[, M_mortality_rate := M_deaths_cum / pop_count]
death_summary[, CL_mortality_rate := CL_deaths_cum / pop_count]
death_summary[, CU_mortality_rate := CU_deaths_cum / pop_count]

#
# Find median death per 100,000
death_summary[, M_deaths_cum_100K := (M_deaths_cum * 100000) / pop_count ]
death_summary[, CL_deaths_cum_100K := (CL_deaths_cum * 100000) / pop_count ]
death_summary[, CU_deaths_cum_100K := (CU_deaths_cum * 100000) / pop_count ]

# Summary for the last month
last_month = as.Date('2020-12-01')
death_summary_last_month = subset(death_summary, date == last_month)


#
# Plot

# crude estimate of the proportion of cases by age
p_proportion_monthly_cases = plot_crude_proportion_monthly_cases_by_age(copy(death_summary), 45)

# proportion of cum deaths by age groups over time
p_proportion_monthly_death = plot_proportion_monthly_death_by_age(copy(death_summary), 0.7, F)

# proportion of cum deaths by age groups in the last month
p_proportion_absolute_cum_death = plot_proportion_absolute_cum_death_by_age(copy(death_summary_last_month))

# mortality rate over time
p_death_per_100K_vs_time_since_10th_cum_death = plot_death_per_100K_vs_time_since_10th_cum_death(copy(select(death_summary, -division)))
p_death_per_100K = plot_death_per_100K(copy(death_summary_last_month))

# USA map proportion of cum deaths and mortality rate on the last month
age_cats = sort(unique(death_summary$age))
plots_prop <- vector('list', length(age_cats))
plots_mortality <- vector('list', length(age_cats))
for(i in 1:length(age_cats)){
  
  tmp = subset(death_summary_last_month, age == age_cats[i])
  
  plots_mortality[[i]] = plot_heat_map_usa(tmp = tmp, 
                                 variable = "M_deaths_cum_100K", 
                                 xlab = "COVID-19 mortality \ncounts per 100,000", 
                                 option_viridis = "magma", 
                                 range_viridis = c(0.15, 0.9), 
                                 limits = NULL, 
                                 main = age_cats[i])
  
  plots_prop[[i]] = plot_heat_map_usa(tmp, 
                                 variable = "M_deaths_prop_cum", 
                                 xlab = "Proportion of COVID-19 \nmortality counts", 
                                 option_viridis = "magma", 
                                 range_viridis = c(0.15, 0.9), 
                                 scale_percent =1,
                                 limits = range(death_summary_last_month$M_deaths_prop_cum), 
                                 main = age_cats[i])
  
}
p_heat_map_usa_mortality_rate <- gridExtra::grid.arrange(grobs=plots_mortality, ncol=2, nrow = 2)
p_heat_map_usa_proportion <- gridExtra::grid.arrange(grobs=plots_prop, ncol=2, nrow = 2)

#
# Tables
# cumulative death, mortality rate and population count
mortality_counts_rate_summary_024 = find_mortality_counts_rate_summary(copy(death_summary_last_month), Age = "0-24", pop_count)
mortality_counts_rate_summary_2549 = find_mortality_counts_rate_summary(copy(death_summary_last_month), Age = "25-49", pop_count)
mortality_counts_rate_summary_5074 = find_mortality_counts_rate_summary(copy(death_summary_last_month), Age = "50-74", pop_count)
mortality_counts_rate_summary_75 = find_mortality_counts_rate_summary(copy(death_summary_last_month), Age = "75+", pop_count)


#
# Find reporting statistics

# find share of 75+ in covid19 attributable deaths
share_75_deaths = find_share_age_deaths(copy(death_summary_last_month), Age = "75+")

# find share of 50-74 in covid19 attributable deaths
share_5074_deaths = find_share_age_deaths(copy(death_summary_last_month), Age = "50-74")

# find share of 25-49 in covid19 attributable deaths
share_2549_deaths = find_share_age_deaths(copy(death_summary_last_month), Age = "25-49")

# find mortality rate nationally
mortality_rate_report = find_mortality_rate_report(copy(death_summary_last_month), Age = "75+")


#
# Save
ggsave(p_proportion_monthly_death, file = file.path(outfig.dir, paste0("ProportionMonthlyDeathsByAge_ntl_age_strata", ".png")), w = 21/1.5, h=29/1.5)
ggsave(p_proportion_monthly_cases, file = file.path(outfig.dir, paste0("ProportionMonthlyCasesByAge_ntl_age_strata.png")), w = 21/1.5, h=29/1.5)
ggsave(p_proportion_absolute_cum_death, file = file.path(outfig.dir, paste0("Proportion_Cum_DeathsByAge", ".png")), w = 10.1, h = 10.1)

ggsave(p_death_per_100K_vs_time_since_10th_cum_death, file = file.path(outfig.dir, paste0("MortalityRateByAge_vs_time_since_10th_CumDeath.png")), w = 15, h = 10)
ggsave(p_death_per_100K, file = file.path(outfig.dir, paste0("MortalityRateByAge.png")), w = 15, h = 10)

ggsave(p_heat_map_usa_mortality_rate, file = file.path(outfig.dir, paste0("heat_map_usa_", "MortalityRateByAge", ".png")), w = 14, h = 10)
ggsave(p_heat_map_usa_proportion, file = file.path(outfig.dir, paste0("heat_map_usa_", "ProprotionDeathsByAge", ".png")), w = 14, h = 10)

saveRDS(list(format(last_month, "%B %d, %Y"), share_75_deaths, share_5074_deaths, share_2549_deaths, mortality_rate_report), 
        file = file.path(outtab.dir, paste0("deaths_ntl_age_strata_summary.rds")), version = 2)
saveRDS(list(format(last_month, "%B %d, %Y"), mortality_counts_rate_summary_024, mortality_counts_rate_summary_2549, mortality_counts_rate_summary_5074, mortality_counts_rate_summary_75), 
        file = file.path(outtab.dir, paste0("mortality_counts_rate_summary.rds")), version = 2)

